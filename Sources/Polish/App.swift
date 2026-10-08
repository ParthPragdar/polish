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
        if !TextAccess.trusted || !Keychain.hasKey || CommandLine.arguments.contains("--demo") { controller.showSettings() }
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
    @objc func settings() { controller.showSettings() }
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
    @Published var settingsSection = "General"
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
    @Published private(set) var isWorking = false
    private var sourceApplication: NSRunningApplication?
    private var target: TextAccess.Target?
    private var task: Task<Void, Never>?
    private var settingsWindow: NSWindow?
    private var panel: FloatingPanel?
    private var operationID = UUID()
    @Published private(set) var automaticApplyFailed = false
    var busy: Bool { isWorking }
    var canApply: Bool { (target != nil || isPreview) && !isWorking }
    var canRetry: Bool { sourceApplication != nil && sourceApplication?.isTerminated == false && !isWorking }
    func retry() { run(mode, source: sourceApplication) }

    func registerHotkeys() {
        do { try hotkeys.register(settings.grammar, settings.prompt); shortcutError = "" }
        catch { shortcutError = (error as NSError).domain }
    }
    func showHistory(id: UUID? = nil) {
        settingsSection = "History"; selectedHistoryID = id
        showSettings()
    }
    func showSettings() {
        if settingsWindow == nil {
            // The glass backdrop runs beneath the transparent title bar; the layout keeps its 610-point body below it.
            let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
            let titlebar = NSWindow.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 800, height: 610), styleMask: style).height - 610
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 610 + titlebar), styleMask: style.union(.fullSizeContentView), backing: .buffered, defer: false)
            window.title = "Polish"; window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: SettingsView(controller: self, settings: settings, titlebarInset: titlebar))
            host.sizingOptions = [] // Otherwise the host adds the title bar's safe area to the window's height again.
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
        self.mode = mode; result = ""; error = ""; original = ""; copied = false; target = nil
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
                case .review:
                    isWorking = false
                    phase = .review; showPanel(at: captured.anchor, interactive: true)
                case .automaticFailure(let failure):
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
            } catch is CancellationError { }
            catch { presentError(error); phase = .error; showPanel(at: target.anchor, interactive: true) }
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
    func dismiss() {
        // Do not interrupt a paste while the clipboard is temporarily owned.
        guard phase != .applying else { return }
        task?.cancel(); task = nil; isWorking = false; operationID = UUID(); panel?.orderOut(nil)
    }
    private func showPanel(at anchor: CGRect?, interactive: Bool) {
        panel?.orderOut(nil)
        let width: CGFloat = automaticApplyFailed ? 320 : (interactive ? 460 : 94)
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
        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        let resolvedAnchor = target.flatMap { access.anchor(for: $0) } ?? anchor
            ?? access.windowAnchor(for: sourceApplication)
            ?? CGRect(x: primary.visibleFrame.midX, y: primary.visibleFrame.midY, width: 1, height: 1)
        let index = PopupPlacement.screenIndex(for: resolvedAnchor, screens: screens.map(\.frame)) ?? 0
        let screen = screens[index]
        window.setFrameOrigin(PopupPlacement.origin(for: size, beside: resolvedAnchor, visibleFrame: screen.visibleFrame))
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { window.alphaValue = 0 }
        if interactive { window.makeKeyAndOrderFront(nil) } else { window.orderFrontRegardless() }
        panel = window
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15
            window.animator().alphaValue = 1
        }
    }
    private func presentError(_ failure: Error) {
        error = failure.localizedDescription
        errorTitle = (failure as? CaptureError)?.title ?? (result.isEmpty ? "Couldn’t finish the rewrite" : "Your rewrite is ready to copy")
        errorNeedsSettings = (failure as? CaptureError).map {
            if case .permission = $0 { return true }; return false
        } ?? (target != nil && result.isEmpty)
    }
    func showLoadingDemo() {
        guard task == nil else { return }
        dismiss(); isPreview = false; automaticApplyFailed = false; target = nil; currentHistoryID = nil; sourceApplication = nil
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
        target = nil; currentHistoryID = nil; error = ""; copied = false; sourceApplication = nil
        mode = .grammar; phase = .review; destination = "Preview"; original = "i has a idea for a better app"; result = "I have an idea for a better app."
        showPanel(at: settingsWindow?.frame, interactive: true)
    }
}

final class FloatingPanel: NSPanel {
    var acceptsKeyboardFocus = false
    override var canBecomeKey: Bool { acceptsKeyboardFocus }
    override var canBecomeMain: Bool { false }
}
