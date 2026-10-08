import AppKit
import ApplicationServices
import PolishCore

@MainActor
final class TextAccess {
    struct Target {
        let application: NSRunningApplication
        /// Nil when the app exposes no editable field: the selection was copied, and the result can only be copied back.
        let element: AXUIElement?
        let original: String
        let fullValue: String?
        let range: NSRange?
        let wholeField: Bool
        let anchor: CGRect?
        var appName: String { application.localizedName ?? "your app" }
        var canReplace: Bool { element != nil }
    }

    enum AccessStatus { case granted, denied, stale }
    /// A grant made for an earlier build can leave AXIsProcessTrusted() true while macOS still
    /// refuses every call from this one, so confirm that a known app actually answers.
    static var status: AccessStatus {
        guard AXIsProcessTrusted() else { return .denied }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return .granted }
        let element = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.3)
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .apiDisabled ? .stale : .granted
    }
    static func openAccessibilitySettings() {
        // Open the pane directly; requesting the AX prompt as well opens a second dialog.
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func belongs(_ element: AXUIElement, to app: NSRunningApplication) -> Bool {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success && pid == app.processIdentifier
    }
    private func prepareAccessibility(_ app: NSRunningApplication) {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.35)
        // These requests are asynchronous in Chromium/Electron. capture() waits for the tree.
        AXUIElementSetAttributeValue(root, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(root, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }
    private func isEditable(_ element: AXUIElement) -> Bool {
        let role = string(element, kAXRoleAttribute) ?? ""
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) { return true }
        if (attribute(element, "AXEditable") as? Bool) == true { return true }
        var writable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &writable)
        // Sliders and other numeric controls also have writable values.
        return writable.boolValue && string(element, kAXValueAttribute) != nil
    }
    private func editableAncestor(_ start: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = start
        for _ in 0..<6 {
            guard let element = current else { break }
            if isEditable(element) { return element }
            current = elementAttribute(element, kAXParentAttribute)
        }
        return nil
    }
    private func focused(_ app: NSRunningApplication) -> AXUIElement? {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        let system = AXUIElementCreateSystemWide()
        // Some Electron apps expose focus on the system-wide element before the app root.
        for owner in [system, root] {
            if let candidate = elementAttribute(owner, kAXFocusedUIElementAttribute), belongs(candidate, to: app),
               let editor = editableAncestor(candidate) { return editor }
        }
        guard let window = elementAttribute(root, kAXFocusedWindowAttribute) else { return nil }
        if let candidate = elementAttribute(window, kAXFocusedUIElementAttribute),
           let editor = editableAncestor(candidate) { return editor }
        // Last resort: inspect only the active window, and only accept an explicitly focused
        // element. Never select the first text field from a window containing several editors.
        var queue = [window]
        var seen = Set<CFHashCode>()
        var cursor = 0
        while cursor < queue.count && cursor < 160 {
            let element = queue[cursor]; cursor += 1
            guard seen.insert(CFHash(element)).inserted else { continue }
            if (attribute(element, kAXFocusedAttribute) as? Bool) == true,
               let editor = editableAncestor(element) { return editor }
            if let candidate = elementAttribute(element, kAXFocusedUIElementAttribute),
               let editor = editableAncestor(candidate) { return editor }
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                queue.append(contentsOf: children.prefix(max(0, 160 - queue.count)))
            }
        }
        return nil
    }
    private func string(_ element: AXUIElement, _ name: String) -> String? { attribute(element, name) as? String }
    private func range(_ element: AXUIElement) -> NSRange? {
        guard let raw = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        guard AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
    private func setRange(_ range: NSRange, on element: AXUIElement) -> Bool {
        var value = CFRange(location: range.location, length: range.length)
        guard let raw = AXValueCreate(.cfRange, &value) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, raw) == .success
    }
    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        let axPosition = position as! AXValue
        let axSize = size as! AXValue
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetType(axPosition) == .cgPoint, AXValueGetType(axSize) == .cgSize,
              AXValueGetValue(axPosition, .cgPoint, &point), AXValueGetValue(axSize, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
    private func selectionBounds(for element: AXUIElement, range selectedRange: NSRange?) -> CGRect? {
        guard let selectedRange else { return nil }
        var range = CFRange(location: selectedRange.location, length: selectedRange.length)
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var raw: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        var rect = CGRect.zero
        guard AXValueGetType(value) == .cgRect, AXValueGetValue(value, .cgRect, &rect) else { return nil }
        return rect
    }
    private func anchor(for element: AXUIElement, selectedRange: NSRange?, app: NSRunningApplication) -> CGRect? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        let window = elementAttribute(element, kAXWindowAttribute) ?? elementAttribute(root, kAXFocusedWindowAttribute)
        // AX uses a top-left origin on the primary display; AppKit uses its bottom-left.
        // Convert once in global points, never using the current/main display's height.
        func convert(_ rect: CGRect?) -> CGRect? {
            rect.map { PopupPlacement.appKitRect(fromAX: $0, primaryScreenTop: primary.frame.maxY) }
        }
        return PopupPlacement.anchor(
            caret: convert(selectionBounds(for: element, range: selectedRange)),
            field: convert(frame(of: element)),
            window: convert(window.flatMap { frame(of: $0) }),
            screens: screens.map(\.frame)
        )
    }
    func anchor(for target: Target) -> CGRect? {
        // Re-read geometry when the result arrives: the source window may have moved.
        guard let element = target.element else { return windowAnchor(for: target.application) }
        return anchor(for: element, selectedRange: range(element), app: target.application)
    }
    func windowAnchor(for app: NSRunningApplication?) -> CGRect? {
        guard let app, let primary = NSScreen.screens.first else { return nil }
        let axWindow = elementAttribute(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute)
        guard let bounds = axWindow.flatMap({ frame(of: $0) }) ?? windowServerFrame(of: app) else { return nil }
        return PopupPlacement.anchor(caret: nil, field: nil,
            window: PopupPlacement.appKitRect(fromAX: bounds, primaryScreenTop: primary.frame.maxY),
            screens: NSScreen.screens.map(\.frame))
    }
    /// The app's frontmost normal window from the window server, for apps whose Accessibility
    /// tree omits geometry. Bounds share AX's top-left origin and need no Screen Recording access.
    private func windowServerFrame(of app: NSRunningApplication) -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in windows where (info[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier
            && (info[kCGWindowLayer as String] as? Int) == 0 {
            if let bounds = info[kCGWindowBounds as String] as? [String: Any],
               let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.width > 80, rect.height > 60 { return rect }
        }
        return nil
    }

    private func ensureFocused(_ target: Target) throws {
        guard let element = target.element else { throw RewriteError.message(Self.copyOnlyMessage(target.appName)) }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.application.processIdentifier,
              let current = focused(target.application), CFEqual(current, element) else {
            throw RewriteError.message("The active text field changed. Return to the original field and retry, or copy the result.")
        }
    }

    func capture(from app: NSRunningApplication?) async throws -> Target {
        switch Self.status {
        case .denied: throw CaptureError.permission
        case .stale: throw CaptureError.permissionStale
        case .granted: break
        }
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw CaptureError.noApplication
        }
        prepareAccessibility(app)
        let element: AXUIElement
        do {
            guard let resolved = try await FocusLookup.resolve(isCurrent: {
                NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
            }, probe: { self.focused(app) }) else {
                return try await captureCopiedSelection(from: app)
            }
            element = resolved
        } catch FocusLookupError.applicationChanged { throw CaptureError.applicationChanged }
        // Check ancestors too: custom secure editors may focus a child of the password field.
        var ancestor: AXUIElement? = element
        for _ in 0..<6 {
            guard let current = ancestor else { break }
            let role = string(current, kAXRoleAttribute) ?? ""
            let subrole = string(current, kAXSubroleAttribute) ?? ""
            guard subrole != kAXSecureTextFieldSubrole, !role.lowercased().contains("secure") else {
                throw RewriteError.message("Password fields cannot be rewritten.")
            }
            ancestor = elementAttribute(current, kAXParentAttribute)
        }
        let full = string(element, kAXValueAttribute)
        let selectedRange = range(element)
        let selected = string(element, kAXSelectedTextAttribute)
        let text: String
        let whole: Bool
        let replacementRange: NSRange?
        if let selected, !selected.isEmpty {
            text = selected; whole = false; replacementRange = selectedRange
        } else if let full, let selectedRange, selectedRange.length > 0,
                  let selection = TextGuard.selectedText(in: full, range: selectedRange) {
            text = selection; whole = false; replacementRange = selectedRange
        } else if let full, !full.isEmpty, (selectedRange?.length == 0 || selected == "") {
            text = full; whole = true; replacementRange = NSRange(location: 0, length: (full as NSString).length)
        } else {
            let copied = try await copySelection(app: app, element: element)
            if !copied.isEmpty {
                text = copied; whole = false; replacementRange = selectedRange
            } else if let full, !full.isEmpty {
                // A number of web editors omit AXSelectedTextRange. Copy returned no
                // selection, so use their readable field value and verify again on apply.
                text = full; whole = true
                replacementRange = NSRange(location: 0, length: (full as NSString).length)
            } else {
                throw RewriteError.message("No text could be read from this field. Select the passage you want to rewrite, then try the shortcut again.")
            }
        }
        try Self.validate(text)
        let target = Target(application: app, element: element, original: text, fullValue: full, range: replacementRange, wholeField: whole, anchor: anchor(for: element, selectedRange: selectedRange, app: app))
        try ensureFocused(target)
        return target
    }

    /// Terminals, canvas editors, and some web apps expose no editable field. A plain Copy of
    /// the selection still lets Polish rewrite it; the result is offered for copying, never pasted blind.
    private func captureCopiedSelection(from app: NSRunningApplication) async throws -> Target {
        let copied = try await copySelection(app: app, element: nil)
        guard !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureError.noEditor(app.localizedName ?? "This app")
        }
        try Self.validate(copied)
        return Target(application: app, element: nil, original: copied, fullValue: nil, range: nil, wholeField: false, anchor: windowAnchor(for: app))
    }
    private static func validate(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RewriteError.message("Write something first, then press the shortcut.") }
        guard text.utf16.count <= 12000 else { throw RewriteError.message("Select a smaller passage (up to 12,000 characters).") }
    }
    static func copyOnlyMessage(_ appName: String) -> String {
        "\(appName) doesn’t let Polish edit its text directly."
    }

    private func ensureUnchanged(_ target: Target) throws {
        if let original = target.fullValue, let element = target.element {
            guard let current = string(element, kAXValueAttribute), TextGuard.unchanged(original: original, current: current) else {
                throw RewriteError.message("Your draft changed while the rewrite was running. Copy the result or run the shortcut again.")
            }
        }
    }

    func apply(_ text: String, to target: Target, reactivate: Bool) async throws {
        if reactivate {
            guard !target.application.isTerminated else { throw RewriteError.message("The original app has closed. Copy the result instead.") }
            target.application.activate(options: [])
            try await Task.sleep(for: .milliseconds(180))
        }
        try ensureFocused(target)
        guard let element = target.element else { return } // ensureFocused already refused a copy-only target.
        try ensureUnchanged(target)
        if let range = target.range {
            // If no full value is exposed, require that the user's selection stayed put.
            if target.fullValue == nil, self.range(element) != range {
                throw RewriteError.message("The selection changed. Select the original text again, or copy the result.")
            }
            if !setRange(range, on: element), self.range(element) != range {
                if target.wholeField && target.fullValue != nil {
                    try ensureFocused(target)
                    sendKey(0) // Select All only inside a verified, unchanged editable field.
                    try await Task.sleep(for: .milliseconds(70))
                    try ensureFocused(target)
                } else {
                    throw RewriteError.message("This editor cannot restore the text selection. Copy the result instead.")
                }
            }
        }
        // Web editors may acknowledge AXSelectedTextRange before publishing the new
        // selection. Wait briefly before treating a stale value as a changed draft.
        var selectionMatches = false
        for attempt in 0..<7 {
            try ensureFocused(target)
            try ensureUnchanged(target)
            if string(element, kAXSelectedTextAttribute) == target.original {
                selectionMatches = true
                break
            }
            if attempt < 6 { try await Task.sleep(for: .milliseconds(40)) }
        }
        if !selectionMatches {
            let copied = try await copySelection(app: target.application, element: element)
            guard copied == target.original else {
                throw RewriteError.message("The selected text no longer matches the original. Copy the result or retry from the field.")
            }
        }
        try ensureFocused(target)
        try ensureUnchanged(target)
        try Task.checkCancellation()
        let clipboard = ClipboardSnapshot()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        let changeCount = NSPasteboard.general.changeCount
        // Paste gives host editors their usual undo operation. Never press Return / Submit.
        sendKey(9)
        // Once paste is sent, preserve the clipboard even if the caller is cancelled.
        try? await Task.sleep(for: .milliseconds(700))
        clipboard.restore(ifUnchanged: changeCount)
    }

    /// Copies the host's selection. With an element, that field must still have focus; without one, only the app is checked.
    private func copySelection(app: NSRunningApplication, element: AXUIElement?) async throws -> String {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              element.map({ element in focused(app).map { CFEqual($0, element) } ?? false }) ?? true else {
            throw RewriteError.message("The active text field changed. Please retry.")
        }
        let snapshot = ClipboardSnapshot()
        let marker = "polish-" + UUID().uuidString
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(marker, forType: .string)
        var count = NSPasteboard.general.changeCount
        defer { snapshot.restore(ifUnchanged: count) }
        sendKey(8)
        for _ in 0..<15 {
            try await Task.sleep(for: .milliseconds(30))
            if NSPasteboard.general.changeCount != count {
                count = NSPasteboard.general.changeCount
                let value = NSPasteboard.general.string(forType: .string) ?? ""
                return value == marker ? "" : value
            }
        }
        return ""
    }

    private func sendKey(_ code: CGKeyCode) {
        let source = CGEventSource(stateID: .privateState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }
}

@MainActor
private struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    init() {
        items = NSPasteboard.general.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        } ?? []
    }
    func restore(ifUnchanged changeCount: Int) {
        let board = NSPasteboard.general
        guard board.changeCount == changeCount else { return }
        board.clearContents()
        let restored = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        board.writeObjects(restored)
    }
}


enum CaptureError: LocalizedError {
    case permission, permissionStale, noApplication, noEditor(String), applicationChanged
    var needsAccessibility: Bool {
        switch self { case .permission, .permissionStale: return true; default: return false }
    }
    var title: String {
        switch self {
        case .permission: return "Accessibility access needed"
        case .permissionStale: return "Turn Accessibility on again"
        case .noApplication: return "Return to your editor"
        case .noEditor: return "Couldn’t read this editor"
        case .applicationChanged: return "The active app changed"
        }
    }
    var errorDescription: String? {
        switch self {
        case .permission: return "Enable Polish in System Settings → Privacy & Security → Accessibility. If it’s already enabled, quit and reopen Polish."
        case .permissionStale: return "macOS is still using the permission from an earlier copy of Polish. In Accessibility settings, remove Polish with the – button, add this copy again, then reopen Polish."
        case .noApplication: return "Place the cursor in the text you want to rewrite, then press your shortcut."
        case .noEditor(let app): return "\(app) didn’t share the text under your cursor. Select the passage you want to rewrite, then press the shortcut again."
        case .applicationChanged: return "Keep the original editor active while Polish reads your text, then try again."
        }
    }
}
