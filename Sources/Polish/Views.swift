import AppKit
import ApplicationServices
import Carbon
import Combine
import PolishCore
import ServiceManagement
import SwiftUI

/// What Polish still needs before it can rewrite text.
struct SetupState: Equatable {
    var access: TextAccess.AccessStatus
    var hasKey: Bool
    var stepsLeft: Int { (access == .granted ? 0 : 1) + (hasKey ? 0 : 1) }
    var ready: Bool { stepsLeft == 0 }
    @MainActor static var current: SetupState { SetupState(access: TextAccess.status, hasKey: Keychain.hasKey) }
}

/// The main window body below the toolbar: Activity, History, or Settings.
struct MainWindowView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var settings: Settings
    var headerHeight: CGFloat
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: headerHeight)
            Rectangle().fill(PolishDesign.hairline).frame(height: 1)
            Group {
                switch controller.settingsSection {
                case "History": HistoryView(controller: controller, history: controller.history, selection: $controller.selectedHistoryID)
                case "Settings": PreferencesView(controller: controller, settings: settings)
                default: OverviewView(controller: controller, history: controller.history, settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 800, height: 610 + headerHeight)
        .background(PolishDesign.window)
        .ignoresSafeArea()
        .foregroundStyle(.white)
        .tint(PolishDesign.green)
        .buttonStyle(PolishButtonStyle())
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in controller.refreshSetup() }
    }
}

/// Centered toolbar title: the app name and its readiness, like a plan badge.
struct ToolbarTitle: View {
    @ObservedObject var controller: AppController
    var body: some View {
        Button { controller.settingsSection = "Overview" } label: {
            HStack(spacing: 8) {
                Text("Polish").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Pill(text: controller.setup.ready ? "READY" : "SETUP", tint: controller.setup.ready ? PolishDesign.green : PolishDesign.orange)
            }
            .fixedSize()
            .frame(width: 140, height: 28) // Toolbar items keep their first size; leave room for either badge.
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .help("Activity")
        .preferredColorScheme(.dark)
    }
}

/// Trailing toolbar buttons; choosing the current screen again returns to Activity.
struct ToolbarActions: View {
    @ObservedObject var controller: AppController
    var body: some View {
        HStack(spacing: 4) {
            HeaderIconButton(systemName: "calendar", help: "History", selected: controller.settingsSection == "History") { toggle("History") }
            HeaderIconButton(systemName: "gearshape", help: "Settings", selected: controller.settingsSection == "Settings") { toggle("Settings") }
        }
        .preferredColorScheme(.dark)
    }
    private func toggle(_ section: String) {
        controller.settingsSection = controller.settingsSection == section ? "Overview" : section
    }
}

/// All preferences on one screen, grouped into charcoal cards.
struct PreferencesView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var settings: Settings
    @State private var key = ""
    @State private var keyMessage = ""
    @State private var loginStatus = LoginItem.status
    @State private var loginMessage = ""
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development build"
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private var setup: SetupState { controller.setup }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BackButton { controller.settingsSection = "Overview" }
                Text("Settings").font(.system(size: 26, weight: .bold))
                Pill(text: "v\(Self.version)")
                Spacer()
            }
            .padding(.horizontal, PolishDesign.pageInset).padding(.top, 24).padding(.bottom, 18)
            ScrollView {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        section("WHEN A REWRITE IS READY") {
                            VStack(alignment: .leading, spacing: 10) {
                                SegmentedPicker(options: [(false, "Review first"), (true, "Apply instantly")], selection: $settings.autoApply)
                                Text(settings.autoApply ? "Your text is replaced as soon as the rewrite arrives. ⌘Z undoes it." : "See and edit the result, then apply it with Return.")
                                    .font(.system(size: 12)).foregroundStyle(PolishDesign.secondaryText).fixedSize(horizontal: false, vertical: true)
                            }.padding(16)
                        }
                        section("SHORTCUTS") {
                            shortcutRow(RewriteMode.grammar.title, binding: $settings.grammar)
                            divider
                            shortcutRow(RewriteMode.prompt.title, binding: $settings.prompt)
                            divider
                            HStack {
                                Text("Use ⌘ or ⌃ with a key. Escape cancels.").font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
                                Spacer()
                                Button("Restore defaults") { settings.grammar = .grammar; settings.prompt = .prompt; controller.registerHotkeys() }
                                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(PolishDesign.green)
                            }.padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        if !controller.shortcutError.isEmpty {
                            Label(controller.shortcutError, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(PolishDesign.orange)
                        }
                        section("THIS MAC") {
                            HStack(spacing: 12) {
                                IconDisc(systemName: setup.access == .granted ? "checkmark.shield" : "hand.raised", size: 32, tint: setup.access == .granted ? PolishDesign.green : PolishDesign.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Accessibility").font(.system(size: 13, weight: .medium))
                                    Text(setup.access == .granted ? "Enabled" : setup.access == .stale ? "Turn on again for this copy" : "Required to read and replace text")
                                        .font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
                                }
                                Spacer()
                                if setup.access != .granted { Button("Open") { TextAccess.openAccessibilitySettings() }.buttonStyle(PolishButtonStyle(primary: true)) }
                            }.padding(14)
                            divider
                            HStack(spacing: 12) {
                                IconDisc(systemName: "power", size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Launch at login").font(.system(size: 13, weight: .medium))
                                    Text(loginStatus == .requiresApproval ? "Allow Polish in System Settings → Login Items" : loginMessage.isEmpty ? "Keep Polish in the menu bar" : loginMessage)
                                        .font(.system(size: 11)).foregroundStyle(loginStatus == .requiresApproval || !loginMessage.isEmpty ? PolishDesign.orange : PolishDesign.secondaryText)
                                }
                                Spacer()
                                Toggle("Launch at login", isOn: Binding(get: { loginStatus == .enabled || loginStatus == .requiresApproval }, set: { enabled in
                                    do { try LoginItem.set(enabled); loginMessage = "" }
                                    catch { loginMessage = "Move Polish to Applications and try again" }
                                    loginStatus = LoginItem.status
                                })).toggleStyle(.switch).labelsHidden()
                            }.padding(14)
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        section("GEMINI LIVE") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("API key").font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Pill(text: setup.hasKey ? "SAVED" : "MISSING", tint: setup.hasKey ? PolishDesign.green : PolishDesign.orange)
                                }
                                SecureField(setup.hasKey ? "Paste a new key to replace it" : "Paste your Gemini API key", text: $key)
                                    .textFieldStyle(.plain).font(.system(size: 13)).padding(.horizontal, 10).frame(height: 32).darkCard(radius: 8, fill: PolishDesign.well)
                                HStack(spacing: 8) {
                                    Button("Save key") {
                                        do { try Keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines)); key = ""; keyMessage = "Saved to Keychain."; controller.refreshSetup() }
                                        catch { keyMessage = "Could not save the key: \(error.localizedDescription)" }
                                    }.buttonStyle(PolishButtonStyle(primary: true)).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    if setup.hasKey {
                                        Button("Remove") { try? Keychain.save(""); key = ""; keyMessage = "Saved key removed."; controller.refreshSetup() }
                                    }
                                    Spacer()
                                    Link("Get a key ↗", destination: URL(string: "https://aistudio.google.com/apikey")!).font(.system(size: 12)).foregroundStyle(PolishDesign.green)
                                }
                                if !keyMessage.isEmpty { Text(keyMessage).font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText) }
                            }.padding(16)
                            divider
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Live model").font(.system(size: 13, weight: .medium))
                                TextField("gemini-3.8-live", text: $settings.model)
                                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced)).padding(.horizontal, 10).frame(height: 32).darkCard(radius: 8, fill: PolishDesign.well)
                                Text("Any Live model your key can use. Default: gemini-3.8-live.").font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
                            }.padding(16)
                        }
                        section("TRY IT") {
                            HStack(spacing: 8) {
                                Button("Preview result") { controller.showDemo() }
                                Button("Preview loading") { controller.showLoadingDemo() }
                                Spacer()
                            }.padding(14)
                        }
                        Label {
                            Text("Only the text you choose is sent to Google. History stays on this Mac, unencrypted. Password fields are never read.")
                        } icon: { Image(systemName: "lock.shield") }
                        .font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, PolishDesign.pageInset).padding(.bottom, 24)
            }
        }
        .onReceive(timer) { _ in loginStatus = LoginItem.status }
    }

    private var divider: some View { Rectangle().fill(PolishDesign.hairline).frame(height: 1) }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(PolishDesign.tertiaryText).padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0, content: content).frame(maxWidth: .infinity, alignment: .leading).darkCard()
        }
    }
    private func shortcutRow(_ title: String, binding: Binding<Shortcut>) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            ShortcutRecorder(shortcut: binding, begin: { controller.hotkeys.suspend() }, end: { controller.registerHotkeys() }) { controller.registerHotkeys() }
                .frame(width: 110, height: 28)
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct ResultView: View {
    @ObservedObject var controller: AppController
    @FocusState private var applyFocused: Bool
    @State private var tab = Tab.result
    private enum Tab { case result, changes }
    private var isError: Bool { controller.phase == .error }
    private var hasResult: Bool { !controller.result.isEmpty && (controller.phase == .review || isError) }
    private var working: Bool { controller.phase == .loading || controller.phase == .applying }
    private var tint: Color { isError ? PolishDesign.orange : PolishDesign.tint(for: controller.mode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    if working { ProgressView().controlSize(.small) }
                    else {
                        Image(systemName: isError ? "exclamationmark" : PolishDesign.symbol(for: controller.mode))
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                    }
                }.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText).lineLimit(1)
                }
                Spacer(minLength: 8)
                if hasResult && !controller.original.isEmpty {
                    SegmentedPicker(options: [(.result, "Result"), (.changes, "Changes")], selection: $tab, compact: true)
                }
                if controller.phase != .applying {
                    Button { controller.dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(PolishDismissStyle()).focusable(false).help("Dismiss").accessibilityLabel("Dismiss popup")
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(18)

            if isError {
                Text(controller.error).font(.system(size: 13)).foregroundStyle(PolishDesign.secondaryText)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18).padding(.bottom, 16)
            }
            if hasResult {
                Group {
                    if tab == .changes {
                        ScrollView {
                            (diffText(original: controller.original, result: controller.result) ?? Text("This rewrite is too long to compare."))
                                .font(.system(size: 14)).lineSpacing(5).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        }
                    } else {
                        TextEditor(text: $controller.result)
                            .font(.system(size: 14)).lineSpacing(5).scrollContentBackground(.hidden).padding(12)
                    }
                }
                .frame(height: min(300, max(150, CGFloat(controller.result.count / 55 + 1) * 22)))
                .darkCard(radius: 12, fill: PolishDesign.well)
                .padding(.horizontal, 18).padding(.bottom, 16)
            }
            if hasResult || isError {
                Rectangle().fill(PolishDesign.hairline).frame(height: 1)
                HStack(spacing: 10) {
                    if hasResult {
                        footerHint
                        Spacer(minLength: 8)
                        if controller.copyOnly {
                            Button { controller.copy() } label: {
                                Label(controller.copied ? "Copied" : "Copy result", systemImage: controller.copied ? "checkmark" : "doc.on.doc")
                            }.buttonStyle(PolishButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                        } else {
                            Button { controller.copy() } label: {
                                Label(controller.copied ? "Copied" : "Copy", systemImage: controller.copied ? "checkmark" : "doc.on.doc")
                            }.buttonStyle(PolishButtonStyle())
                            Button("Apply rewrite") { controller.apply() }.buttonStyle(PolishButtonStyle(primary: true))
                                .disabled(!controller.canApply || controller.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .keyboardShortcut(.defaultAction)
                                .focusable()
                                .focused($applyFocused)
                                .focusEffectDisabled()
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(applyFocused ? 0.35 : 0), lineWidth: 2).padding(-3).allowsHitTesting(false))
                        }
                    } else {
                        Label("No text was changed", systemImage: "checkmark.shield").font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
                        Spacer(minLength: 8)
                        if controller.errorNeedsAccessibility {
                            Button("Open Accessibility Settings") { controller.dismiss(); TextAccess.openAccessibilitySettings() }.buttonStyle(PolishButtonStyle(primary: true))
                        } else if controller.errorNeedsSettings {
                            Button("Open Settings") { controller.dismiss(); controller.showSettings(section: "Settings") }.buttonStyle(PolishButtonStyle(primary: true))
                        } else if controller.canRetry {
                            Button("Try again") { controller.retry() }.buttonStyle(PolishButtonStyle(primary: true))
                        } else {
                            Button("Got it") { controller.dismiss() }.buttonStyle(PolishButtonStyle(primary: true))
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 18).padding(.vertical, 14)
            }
        }
        .foregroundStyle(.white)
        .darkCard(radius: PolishDesign.popupRadius, fill: Color(white: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: PolishDesign.popupRadius, style: .continuous))
        .tint(PolishDesign.green)
        .preferredColorScheme(.dark)
        .task { focusApplyIfReady() }
        .onChange(of: controller.canApply) { _, ready in
            if ready { focusApplyIfReady() }
        }
    }
    @ViewBuilder private var footerHint: some View {
        if controller.copiedForPaste {
            Label("Copied — press ⌘V to paste", systemImage: "doc.on.clipboard").font(.system(size: 11, weight: .semibold)).foregroundStyle(PolishDesign.green)
        } else if controller.copyOnly {
            Text("Copy, then paste with ⌘V").font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
        } else {
            Text("↩ apply  ·  esc close").font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
        }
    }
    private func focusApplyIfReady() {
        if controller.canApply && hasResult { applyFocused = true }
    }
    private var subtitle: String {
        if isError { return "Your original text is safe" }
        let app = controller.destination.isEmpty ? "" : " · \(controller.destination)"
        return PolishDesign.shortTitle(for: controller.mode) + app
    }
    private var title: String {
        switch controller.phase {
        case .loading: return controller.mode == .grammar ? "Polishing your words…" : "Refining your prompt…"
        case .applying: return "Applying your rewrite…"
        case .idle: return ""
        case .error: return controller.errorTitle
        case .review: return controller.mode == .grammar ? "Review correction" : "Review prompt"
        }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    var begin: () -> Void
    var end: () -> Void
    var changed: () -> Void
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        // A flat key-cap look to match the dark cards, instead of a light system bezel.
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.backgroundColor = NSColor(white: 0.115, alpha: 1).cgColor
        button.layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor
        button.layer?.borderWidth = 1
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.contentTintColor = .white
        return button
    }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.onBegin = begin; button.onEnd = end
        button.shortcut = shortcut
        if !button.recording { button.title = shortcut.label }
        button.onRecord = { shortcut = $0; changed() }
    }
}

final class RecorderButton: NSButton {
    var shortcut = Shortcut.grammar
    var onRecord: ((Shortcut) -> Void)?
    var onBegin: (() -> Void)?
    var onEnd: (() -> Void)?
    var recording = false
    private var monitor: Any?
    override init(frame: NSRect) { super.init(frame: frame); target = self; action = #selector(record) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func record() {
        stop(); recording = true; title = "Press keys…"; onBegin?()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.stop(); return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command) || flags.contains(.control),
                  let chars = event.charactersIgnoringModifiers?.uppercased(), chars.count == 1,
                  chars.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(.punctuationCharacters).union(.symbols).contains($0) }),
                  ![36, 48, 49, 51, 53, 76, 117, 123, 124, 125, 126].contains(event.keyCode) else { NSSound.beep(); return nil }
            var modifiers: UInt32 = 0; var label = ""
            if flags.contains(.control) { modifiers |= UInt32(controlKey); label += "⌃" }
            if flags.contains(.option) { modifiers |= UInt32(optionKey); label += "⌥" }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey); label += "⇧" }
            if flags.contains(.command) { modifiers |= UInt32(cmdKey); label += "⌘" }
            label += chars
            let value = Shortcut(key: UInt32(event.keyCode), modifiers: modifiers, label: label)
            self.shortcut = value; self.stop(); self.onRecord?(value); return nil
        }
    }
    private func stop() { let wasRecording = recording; if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; recording = false; title = shortcut.label; if wasRecording { onEnd?() } }
    override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { stop() }; super.viewWillMove(toWindow: newWindow) }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
}
