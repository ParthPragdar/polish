import AppKit
import SwiftUI
import PolishCore

@main
enum PolishApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .darkAqua) // Polish is designed for a dark theme only.
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let controller = AppController()
    private var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Polish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; mainMenu.addItem(appItem)
        let editItem = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editItem.submenu = editMenu; mainMenu.addItem(editItem); NSApplication.shared.mainMenu = mainMenu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "text.badge.checkmark", accessibilityDescription: "Polish")
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        status.menu = menu
        rebuildMenu(menu)
        controller.registerHotkeys()
        controller.hotkeys.onPress = { [weak self] id in self?.controller.run(id == 0 ? .grammar : .prompt) }
        // Stay in the menu bar when launched at login; open Settings only while setup is incomplete.
        if TextAccess.status != .granted || !Keychain.hasKey || CommandLine.arguments.contains("--demo") { controller.showSettings() }
        if CommandLine.arguments.contains("--demo") { controller.showDemo() }
    }
    func menuWillOpen(_ menu: NSMenu) { rebuildMenu(menu) }
    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        func action(_ title: String, _ selector: Selector, id: UUID? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; item.representedObject = id?.uuidString
            menu.addItem(item)
        }
        action("Correct grammar", #selector(grammar))
        action("Refine prompt", #selector(prompt))
        action("Settings…", #selector(settings))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem.sectionHeader(title: "Recent rewrites"))
        if controller.history.items.isEmpty {
            let empty = NSMenuItem(title: "Your rewrites will appear here", action: nil, keyEquivalent: "")
            empty.isEnabled = false; menu.addItem(empty)
        }
        for entry in controller.history.recentItems {
            let preview = entry.preview
            action(String(preview.prefix(52)) + (preview.count > 52 ? "…" : ""), #selector(openHistoryItem(_:)), id: entry.id)
            menu.items.last?.image = NSImage(systemSymbolName: entry.mode == .grammar ? "text.badge.checkmark" : "sparkles", accessibilityDescription: entry.mode.title)
            menu.items.last?.toolTip = "\(entry.mode.title) · \(entry.createdAt.formatted())"
        }
        action("View all history…", #selector(openHistory))
        menu.addItem(.separator())
        action("Quit Polish", #selector(quitApp))
    }
    @objc func openHistory() { controller.showHistory() }
    @objc func openHistoryItem(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let id = UUID(uuidString: value) else { return }
        controller.showHistory(id: id)
    }
    @objc func grammar() { controller.run(.grammar) }
    @objc func prompt() { controller.run(.prompt) }
    @objc func settings() { controller.showSettings(section: "Settings") }
    @objc func quitApp() { NSApplication.shared.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { controller.showSettings(); return true }
}

@MainActor
final class AppController: ObservableObject {
    enum Phase { case idle, loading, review, applying, error }
    let settings = Settings()
    let history = RewriteHistory()
    let hotkeys = Hotkeys()
    let access = TextAccess()
    @Published var phase: Phase = .idle
    /// The main window's screen: "Overview", "History", or "Settings".
    @Published var settingsSection = "Overview"
    @Published private(set) var setup = SetupState.current
    @Published var selectedHistoryID: UUID?
    private var currentHistoryID: UUID?
    private var isPreview = false
    @Published var result = ""
    @Published var original = ""
    @Published var error = ""
    @Published var mode: RewriteMode = .grammar
    @Published var destination = ""
    @Published var shortcutError = ""
    @Published var copied = false
    @Published var errorTitle = "Couldn’t finish the rewrite"
    @Published var errorNeedsSettings = false
    @Published var errorNeedsAccessibility = false
    /// The result was put on the clipboard because Polish couldn't paste it safely.
    @Published private(set) var copiedForPaste = false
    @Published private(set) var isWorking = false
    private var sourceApplication: NSRunningApplication?
    private var target: TextAccess.Target?
    private var task: Task<Void, Never>?
    private var settingsWindow: NSWindow?
    private var panel: FloatingPanel?
    private var toast: FloatingPanel?
    private lazy var toolbarItems = MainToolbar(controller: self)
    private var operationID = UUID()
    @Published private(set) var automaticApplyFailed = false
    var busy: Bool { isWorking }
    var canApply: Bool { (target?.canReplace == true || isPreview) && !isWorking }
    /// The source app exposes no editable field, so the result can only be copied.
    var copyOnly: Bool { target.map { !$0.canReplace } ?? false }
    var canRetry: Bool { sourceApplication != nil && sourceApplication?.isTerminated == false && !isWorking }
    func retry() { run(mode, source: sourceApplication) }

    func registerHotkeys() {
        do { try hotkeys.register(settings.grammar, settings.prompt); shortcutError = "" }
        catch { shortcutError = (error as NSError).domain }
    }
    func refreshSetup() {
        let current = SetupState.current
        if current != setup { setup = current }
    }
    func showHistory(id: UUID? = nil) {
        selectedHistoryID = id
        showSettings(section: "History")
    }
    func showSettings(section: String? = nil) {
        if let section { settingsSection = section }
        refreshSetup()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 610), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Polish"; window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true; window.titlebarSeparatorStyle = .none
            window.backgroundColor = NSColor(white: 0.155, alpha: 1)
            // A unified toolbar gives a tall header with vertically centered window buttons, and hosts
            // the title and actions as real toolbar items so their clicks never become window drags.
            let toolbar = NSToolbar(identifier: "PolishMain")
            toolbar.delegate = toolbarItems
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.centeredItemIdentifiers = [MainToolbar.title]
            window.toolbar = toolbar; window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            // The content view spans the whole frame; keep a 610-point body below the header.
            let header = window.frame.height - window.contentLayoutRect.height
            window.setContentSize(NSSize(width: 800, height: 610 + header))
            let host = NSHostingView(rootView: MainWindowView(controller: self, settings: settings, headerHeight: header))
            host.sizingOptions = [] // Otherwise the host adds the header's safe area to the window's height again.
            window.contentView = host
            window.center(); settingsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func run(_ mode: RewriteMode, source: NSRunningApplication? = nil) {
        guard task == nil else { NSSound.beep(); return }
        // Capture the destination before dismissing our own panel or yielding to a Task.
        let foreground = NSWorkspace.shared.frontmostApplication
        let requestedApp = source ?? (foreground?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : foreground)
        dismiss()
        currentHistoryID = nil
        isPreview = false
        automaticApplyFailed = false
        self.sourceApplication = requestedApp
        self.mode = mode; result = ""; error = ""; original = ""; copied = false; copiedForPaste = false; target = nil
        destination = requestedApp?.localizedName ?? ""
        errorNeedsSettings = false; isWorking = true; phase = .loading
        let id = UUID(); operationID = id
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        task = Task {
            do {
                if let source { source.activate(options: []) }
                // Let the shortcut modifiers release and let an explicit Retry return to its app.
                try await Task.sleep(for: .milliseconds(220))
                let captured = try await access.capture(from: requestedApp)
                target = captured; original = captured.original; destination = captured.appName
                phase = .loading; showPanel(at: captured.anchor, interactive: false)
                let key = Keychain.read()
                result = try await GeminiClient().rewrite(captured.original, mode: mode, key: key, model: model)
                try Task.checkCancellation()
                currentHistoryID = history.record(mode: mode, sourceApp: captured.appName, original: captured.original, result: result)
                let outcome = try await RewriteDelivery.deliver(automatically: settings.autoApply) {
                    phase = .applying
                    // Remove the loading panel before restoring the host editor's selection.
                    panel?.orderOut(nil)
                    try await access.apply(result, to: captured, reactivate: false)
                }
                switch outcome {
                case .applied:
                    phase = .idle
                    showToast(at: captured.anchor)
                case .review:
                    isWorking = false
                    phase = .review; showPanel(at: captured.anchor, interactive: true)
                case .automaticFailure(let failure):
                    copyForPaste()
                    presentError(failure)
                    automaticApplyFailed = true
                    phase = .error
                    showPanel(at: captured.anchor, interactive: false)
                }
            } catch is CancellationError { }
            catch {
                guard operationID == id else { return }
                presentError(error)
                phase = .error; showPanel(at: target?.anchor ?? access.windowAnchor(for: sourceApplication), interactive: true)
            }
            if operationID == id { task = nil; isWorking = false }
        }
    }
    func apply() {
        if isPreview && task == nil {
            isPreview = false; panel?.orderOut(nil); phase = .idle
            return
        }
        guard task == nil, let target, !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        phase = .applying; error = ""; isWorking = true
        panel?.orderOut(nil)
        task = Task {
            do {
                try await access.apply(result, to: target, reactivate: true)
                saveEditedResult()
                panel?.orderOut(nil)
                phase = .idle
                showToast(at: target.anchor)
            } catch is CancellationError { }
            catch { copyForPaste(); presentError(error); phase = .error; showPanel(at: target.anchor, interactive: true) }
            task = nil; isWorking = false
        }
    }
    func openFailedResult() {
        let id = currentHistoryID
        dismiss()
        showHistory(id: id)
    }
    private func saveEditedResult() {
        if let id = currentHistoryID { history.updateResult(id: id, result: result) }
    }
    func copy() {
        saveEditedResult()
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(result, forType: .string); copied = true
    }
    /// When a paste can't be verified, leave the result one ⌘V away instead of making the user copy it.
    private func copyForPaste() {
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        copy(); copiedForPaste = true
    }
    func dismiss() {
        // Do not interrupt a paste while the clipboard is temporarily owned.
        guard phase != .applying else { return }
        task?.cancel(); task = nil; isWorking = false; operationID = UUID(); panel?.orderOut(nil)
    }
    private func showPanel(at anchor: CGRect?, interactive: Bool) {
        panel?.orderOut(nil)
        let width: CGFloat = automaticApplyFailed ? 320 : (interactive ? 460 : 236)
        let root: AnyView
        if automaticApplyFailed {
            root = AnyView(AutomaticApplyNotice(controller: self).frame(width: width))
        } else if interactive {
            root = AnyView(ResultView(controller: self).frame(width: width))
        } else {
            root = AnyView(LoadingIndicator(controller: self).frame(width: width, height: 44))
        }
        let content = NSHostingView(rootView: root)
        let size = CGSize(width: width, height: content.fittingSize.height)
        let window = FloatingPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.acceptsKeyboardFocus = interactive
        window.isFloatingPanel = true; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.hidesOnDeactivate = false; window.isReleasedWhenClosed = false
        window.contentView = content
        window.isMovableByWindowBackground = true
        window.title = "Polish · " + mode.title
        guard let origin = origin(for: size, near: anchor) else { return }
        window.setFrameOrigin(origin)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { window.alphaValue = 0 }
        if interactive { window.makeKeyAndOrderFront(nil) } else { window.orderFrontRegardless() }
        panel = window
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15
            window.animator().alphaValue = 1
        }
    }
    /// Beside the caret or field when known, else the source window, else centered on the display under the pointer.
    private func origin(for size: CGSize, near anchor: CGRect?) -> CGPoint? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        let pointerScreen = screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? primary
        let resolvedAnchor = target.flatMap { access.anchor(for: $0) } ?? anchor
            ?? access.windowAnchor(for: sourceApplication)
            ?? CGRect(x: pointerScreen.visibleFrame.midX - size.width / 2, y: pointerScreen.visibleFrame.midY, width: size.width, height: 1)
        let index = PopupPlacement.screenIndex(for: resolvedAnchor, screens: screens.map(\.frame)) ?? 0
        return PopupPlacement.origin(for: size, beside: resolvedAnchor, visibleFrame: screens[index].visibleFrame)
    }
    /// A brief, click-through confirmation after text is replaced.
    private func showToast(at anchor: CGRect?) {
        toast?.orderOut(nil)
        let content = NSHostingView(rootView: AppliedToast())
        let size = content.fittingSize
        guard let origin = origin(for: size, near: anchor) else { return }
        let window = FloatingPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.level = .floating; window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.ignoresMouseEvents = true; window.isReleasedWhenClosed = false
        window.contentView = content
        window.orderFrontRegardless()
        toast = window
        Task { [weak self, weak window] in
            try? await Task.sleep(for: .seconds(1.6))
            guard let window, self?.toast === window else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.25
                window.animator().alphaValue = 0
            }
            window.orderOut(nil)
            if self?.toast === window { self?.toast = nil }
        }
    }
    private func presentError(_ failure: Error) {
        error = failure.localizedDescription
        errorTitle = (failure as? CaptureError)?.title ?? (result.isEmpty ? "Couldn’t finish the rewrite" : "Your rewrite is ready to copy")
        errorNeedsAccessibility = (failure as? CaptureError)?.needsAccessibility ?? false
        errorNeedsSettings = !errorNeedsAccessibility && (failure as? CaptureError) == nil && target != nil && result.isEmpty
    }
    func showLoadingDemo() {
        guard task == nil else { return }
        dismiss(); isPreview = false; automaticApplyFailed = false; target = nil; currentHistoryID = nil; sourceApplication = nil; copiedForPaste = false
        phase = .loading; isWorking = true
        showPanel(at: settingsWindow?.frame, interactive: false)
        panel?.acceptsKeyboardFocus = true
        panel?.makeKeyAndOrderFront(nil) // The preview can take focus; live loading never does.
        task = Task {
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            panel?.orderOut(nil); phase = .idle; isWorking = false; task = nil
        }
    }
    func showDemo() {
        guard task == nil else { return }
        automaticApplyFailed = false; isPreview = true
        target = nil; currentHistoryID = nil; error = ""; copied = false; copiedForPaste = false; sourceApplication = nil
        mode = .grammar; phase = .review; destination = "Preview"; original = "i has a idea for a better app"; result = "I have an idea for a better app."
        showPanel(at: settingsWindow?.frame, interactive: true)
    }
}

final class FloatingPanel: NSPanel {
    var acceptsKeyboardFocus = false
    override var canBecomeKey: Bool { acceptsKeyboardFocus }
    override var canBecomeMain: Bool { false }
}

/// Supplies the main window's toolbar: a centered title and trailing screen buttons.
@MainActor
final class MainToolbar: NSObject, NSToolbarDelegate {
    static let title = NSToolbarItem.Identifier("polish.title")
    static let actions = NSToolbarItem.Identifier("polish.actions")
    private unowned let controller: AppController
    init(controller: AppController) { self.controller = controller }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.title, .flexibleSpace, Self.actions]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        let view: NSView
        switch identifier {
        case Self.title: view = NSHostingView(rootView: ToolbarTitle(controller: controller))
        case Self.actions: view = NSHostingView(rootView: ToolbarActions(controller: controller))
        default: return nil
        }
        view.setFrameSize(view.fittingSize)
        item.view = view
        item.isBordered = false
        return item
    }
}
