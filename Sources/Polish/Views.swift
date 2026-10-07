import AppKit
import ApplicationServices
import Carbon
import Combine
import SwiftUI

private let accent = PolishDesign.accent
private let canvas = PolishDesign.canvas

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var settings: Settings
    private var section: String { controller.settingsSection }
    @State private var key = ""
    @State private var keyMessage = ""
    @State private var trusted = TextAccess.trusted
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "text.badge.checkmark").font(.system(size: 23)).foregroundStyle(accent)
                    Text("Polish").font(.system(size: 25, weight: .semibold, design: .rounded))
                }.padding(.top, 20)
                VStack(spacing: 6) {
                    nav("General", "slider.horizontal.3")
                    nav("History", "clock.arrow.circlepath")
                    nav("Shortcuts", "command")
                    nav("Gemini Live", "sparkles")
                }
                Spacer()
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 6) {
                        Circle().fill(trusted ? accent : .orange).frame(width: 6, height: 6)
                        Text(trusted ? "Ready for your words" : "One step to get ready").font(.system(size: 11, weight: .medium))
                    }
                    Text("A little clarity.\nWherever you write.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                    Divider().padding(.vertical, 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Developed by").font(.system(size: 10)).foregroundStyle(.secondary)
                        Text("Parth Pragdar").font(.system(size: 12, weight: .semibold))
                    }
                }.padding(.bottom, 24)
            }.padding(.horizontal, 22).frame(width: 195).background(canvas)
            Rectangle().fill(Color.black.opacity(0.07)).frame(width: 1)
            Group {
                if section == "History" {
                    HistoryView(history: controller.history, selection: $controller.selectedHistoryID)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if section == "General" { general }
                            else if section == "Shortcuts" { shortcuts }
                            else { connection }
                        }.padding(PolishDesign.pageInset).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.background(PolishDesign.page)
        }
        .frame(width: 800, height: 610).tint(accent)
        .buttonStyle(PolishButtonStyle())
        .preferredColorScheme(.light)
        .onReceive(timer) { _ in trusted = TextAccess.trusted }
    }
    private func nav(_ title: String, _ symbol: String) -> some View {
        Button { controller.settingsSection = title } label: {
            HStack(spacing: 11) { Image(systemName: symbol).frame(width: 18); Text(title); Spacer() }
                .font(.system(size: 13, weight: section == title ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(section == title ? accent : Color.primary)
                .background(section == title ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
        }.buttonStyle(PolishRowStyle()).focusEffectDisabled()
    }
    private func heading(_ eyebrow: String, _ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(accent)
            Text(title).font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }
    private var general: some View {
        Group {
            heading("WRITE WITH CONFIDENCE", "Your words, a little clearer.", "Fix a sentence or shape a better prompt, right in the app you’re using.")
            VStack(alignment: .leading, spacing: 12) {
                Text("WHEN A REWRITE IS READY").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                modeCard(false, "Review before applying", "See the result, make an edit, then Apply or Copy.", "rectangle.and.pencil.and.ellipsis")
                modeCard(true, "Apply automatically", "A small loading indicator, then your text is replaced.", "bolt")
            }
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: trusted ? "checkmark.shield" : "hand.raised").foregroundStyle(accent)
                    Text("Accessibility access").fontWeight(.medium)
                    Spacer()
                    Text(trusted ? "Enabled" : "Required").font(.system(size: 11, weight: .medium)).foregroundStyle(trusted ? accent : .orange)
                }
                Text("Lets Polish read the focused text and paste the rewrite back into your app.").font(.system(size: 12)).foregroundStyle(.secondary)
                if !trusted { Button("Open Accessibility Settings") { TextAccess.openAccessibilitySettings() } }
            }.padding(18).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            Label("Select a passage, or leave the cursor in a field to rewrite all its text.", systemImage: "cursorarrow.click.2").font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Preview result popup") { controller.showDemo() }
                Button("Preview loading") { controller.showLoadingDemo() }
            }.font(.system(size: 12))
            if !controller.shortcutError.isEmpty { Text(controller.shortcutError).foregroundStyle(.red).font(.caption) }
        }
    }
    private func modeCard(_ automatic: Bool, _ title: String, _ subtitle: String, _ icon: String) -> some View {
        Button { settings.autoApply = automatic } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 21)).foregroundStyle(accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: settings.autoApply == automatic ? "checkmark.circle.fill" : "circle").foregroundStyle(settings.autoApply == automatic ? accent : Color.secondary.opacity(0.4))
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).background(settings.autoApply == automatic ? accent.opacity(0.055) : .white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(settings.autoApply == automatic ? accent.opacity(0.45) : Color.black.opacity(0.08), lineWidth: 1))
        }.buttonStyle(PolishRowStyle()).focusEffectDisabled()
    }
    private var shortcuts: some View {
        Group {
            heading("A SMALL SHORTCUT", "Stay in your flow.", "Two actions, available across your Mac. Click a shortcut to record your own.")
            shortcutRow("Correct grammar", "Keep your voice. Fix spelling, grammar, and phrasing.", binding: $settings.grammar)
            shortcutRow("Refine prompt", "Turn a rough request into clear instructions for AI.", binding: $settings.prompt)
            Text("Use ⌘ or ⌃ together with a letter, number, or punctuation key. Press Escape to cancel recording.").font(.system(size: 12)).foregroundStyle(.secondary)
            if !controller.shortcutError.isEmpty { Label(controller.shortcutError, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption) }
            Button("Restore default shortcuts") {
                settings.grammar = .grammar; settings.prompt = .prompt; controller.registerHotkeys()
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("THE EVERYDAY FLOW").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(accent)
                Text("01   Write in Chrome, an AI chat, or your editor.")
                Text("02   Select a passage, or keep the cursor in the field.")
                Text("03   Press your shortcut. Polish takes it from here.")
            }.font(.system(size: 12)).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(canvas, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private func shortcutRow(_ title: String, _ subtitle: String, binding: Binding<Shortcut>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) { Text(title).fontWeight(.semibold); Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary) }
            Spacer()
            ShortcutRecorder(shortcut: binding, begin: { controller.hotkeys.suspend() }, end: { controller.registerHotkeys() }) { controller.registerHotkeys() }.frame(width: 116, height: 35)
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 12))
    }
    private var connection: some View {
        Group {
            heading("POWERED BY GEMINI LIVE", "Bring your own key.", "Polish connects directly to Google’s Live API. Your key stays in this Mac’s Keychain.")
            VStack(alignment: .leading, spacing: 12) {
                Text("Gemini API key").fontWeight(.semibold)
                SecureField("Paste a key to save or replace it", text: $key).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save key") {
                        do { try Keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines)); key = ""; keyMessage = "Key saved to Keychain." }
                        catch { keyMessage = "Could not save the key: \(error.localizedDescription)" }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove saved key") { try? Keychain.save(""); key = ""; keyMessage = "Saved key removed." }
                    Spacer()
                    Link("Get an API key ↗", destination: URL(string: "https://aistudio.google.com/apikey")!)
                }.font(.system(size: 12))
                if !keyMessage.isEmpty { Text(keyMessage).font(.caption).foregroundStyle(accent) }
                Divider().padding(.vertical, 4)
                Text("Live model").fontWeight(.semibold)
                TextField("gemini-3.8-live", text: $settings.model).textFieldStyle(.roundedBorder)
                Text("Use a Live model available to your Google project. Default: gemini-3.8-live.").font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 12) {
                Label("Only the text you ask to rewrite is sent", systemImage: "lock.shield").fontWeight(.medium)
                Text("Each shortcut sends your selection or current field to Google. Your last 80 rewrites are saved locally in History. Your entire screen is never sent. Password fields are excluded.")
                Text("Live returns the rewrite through a structured function call. No microphone access or audio playback is used. Google API usage charges may apply.")
            }.font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }
}

struct ResultView: View {
    @ObservedObject var controller: AppController
    @FocusState private var applyFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var popupAccent: Color { PolishDesign.accent(for: colorScheme) }
    private var warningAccent: Color { colorScheme == .dark ? Color(red: 0.92, green: 0.72, blue: 0.43) : Color(red: 0.64, green: 0.39, blue: 0.12) }
    private var isError: Bool { controller.phase == .error }
    private var hasResult: Bool { !controller.result.isEmpty && (controller.phase == .review || isError) }
    private var working: Bool { controller.phase == .loading || controller.phase == .applying }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(isError ? Color.orange.opacity(0.10) : popupAccent.opacity(0.09))
                    if working { ProgressView().controlSize(.small) }
                    else {
                        Image(systemName: isError ? "text.magnifyingglass" : "text.badge.checkmark")
                            .font(.system(size: 19, weight: .medium)).foregroundStyle(isError ? warningAccent : popupAccent)
                    }
                }.frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(isError ? "Your original text is safe" : "Ready for your finishing touch")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                if controller.phase != .applying {
                    Button { controller.dismiss() } label: {
                        Image(systemName: "xmark")
                    }.buttonStyle(PolishDismissStyle()).focusable(false).help("Dismiss").accessibilityLabel("Dismiss popup")
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(20)

            if isError {
                Text(controller.error).font(.system(size: 13)).foregroundStyle(.secondary)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20).padding(.bottom, 18)
            }
            if hasResult {
                TextEditor(text: $controller.result)
                    .font(.system(size: 14)).lineSpacing(5).scrollContentBackground(.hidden)
                    .padding(12).frame(height: min(300, max(150, CGFloat(controller.result.count / 55 + 1) * 22)))
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
                    .padding(.horizontal, 20).padding(.bottom, 18)
            }
            if hasResult || isError {
                Rectangle().fill(Color.primary.opacity(0.065)).frame(height: 1)
                HStack(spacing: 10) {
                    if hasResult {
                        Text("Edit before applying").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Button { controller.copy() } label: {
                            Label(controller.copied ? "Copied" : "Copy", systemImage: controller.copied ? "checkmark" : "doc.on.doc")
                        }.buttonStyle(PolishButtonStyle())
                        Button("Apply rewrite") { controller.apply() }.buttonStyle(PolishButtonStyle(primary: true))
                            .disabled(!controller.canApply || controller.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.defaultAction)
                            .focusable()
                            .focused($applyFocused)
                            .focusEffectDisabled()
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(popupAccent.opacity(applyFocused ? 0.4 : 0), lineWidth: 2).padding(-3).allowsHitTesting(false))
                    } else {
                        Label("No text was changed", systemImage: "checkmark.shield").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        if controller.errorNeedsSettings {
                            Button("Open Settings") { controller.dismiss(); controller.showSettings() }.buttonStyle(PolishButtonStyle(primary: true))
                        } else if controller.canRetry {
                            Button("Try again") { controller.retry() }.buttonStyle(PolishButtonStyle(primary: true))
                        } else {
                            Button("Got it") { controller.dismiss() }.buttonStyle(PolishButtonStyle(primary: true))
                        }
                    }
                }.controlSize(.regular).font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: PolishDesign.popupRadius))
        .overlay(RoundedRectangle(cornerRadius: PolishDesign.popupRadius).stroke(Color.primary.opacity(0.09)))
        .clipShape(RoundedRectangle(cornerRadius: PolishDesign.popupRadius)).tint(popupAccent)
        .task { focusApplyIfReady() }
        .onChange(of: controller.canApply) { _, ready in
            if ready { focusApplyIfReady() }
        }
    }
    private func focusApplyIfReady() {
        if controller.canApply && hasResult { applyFocused = true }
    }
    private var title: String {
        switch controller.phase {
        case .loading: return controller.mode == .grammar ? "Polishing your words…" : "Refining your prompt…"
        case .applying: return "Applying your rewrite…"
        case .idle: return ""
        case .error: return controller.errorTitle
        case .review: return controller.mode == .grammar ? "Review your correction" : "Review your prompt"
        }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    var begin: () -> Void
    var end: () -> Void
    var changed: () -> Void
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton(); button.bezelStyle = .rounded; return button
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
