import AppKit
import Carbon
import Security
import ServiceManagement
import SwiftUI

struct Shortcut: Codable, Equatable {
    var key: UInt32
    var modifiers: UInt32
    var label: String
    static let grammar = Shortcut(key: 5, modifiers: UInt32(controlKey | optionKey), label: "⌃⌥G")
    static let prompt = Shortcut(key: 35, modifiers: UInt32(controlKey | optionKey), label: "⌃⌥P")
}

@MainActor
final class Settings: ObservableObject {
    @Published var autoApply: Bool { didSet { defaults.set(autoApply, forKey: "autoApply") } }
    @Published var model: String { didSet { defaults.set(model, forKey: "model") } }
    @Published var grammar: Shortcut { didSet { save(grammar, "grammar") } }
    @Published var prompt: Shortcut { didSet { save(prompt, "prompt") } }
    private let defaults = UserDefaults.standard
    init() {
        autoApply = defaults.bool(forKey: "autoApply")
        model = defaults.string(forKey: "model") ?? "gemini-3.8-live"
        grammar = defaults.data(forKey: "grammar").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .grammar
        prompt = defaults.data(forKey: "prompt").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .prompt
    }
    private func save(_ value: Shortcut, _ key: String) { defaults.set(try? JSONEncoder().encode(value), forKey: key) }
}

enum Keychain {
    private static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.polish.mac", kSecAttrAccount as String: "gemini-api-key"] }
    static func read() -> String {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
    /// Checks for the item without reading its secret, so a rebuilt app never triggers a Keychain prompt at launch.
    static var hasKey: Bool { SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess }
    static func save(_ key: String) throws {
        if key.isEmpty { SecItemDelete(query as CFDictionary); return }
        let data = Data(key.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
}

/// The system's login-item registration is the source of truth; nothing is mirrored in UserDefaults.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

@MainActor
final class Hotkeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var onPress: ((UInt32) -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let owner = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { owner.onPress?(id.id) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func suspend() { refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll() }
    func register(_ grammar: Shortcut, _ prompt: Shortcut) throws {
        refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll()
        guard grammar.key != prompt.key || grammar.modifiers != prompt.modifiers else {
            throw NSError(domain: "Choose two different shortcuts.", code: 1)
        }
        for (index, shortcut) in [grammar, prompt].enumerated() {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.key, shortcut.modifiers, EventHotKeyID(signature: 0x504F4C49, id: UInt32(index)), GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else {
                refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll()
                throw NSError(domain: "A shortcut is already in use. Record another combination.", code: Int(status))
            }
            refs.append(ref)
        }
    }
}
