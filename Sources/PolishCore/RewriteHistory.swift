import Combine
import Foundation

public struct HistoryItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let mode: RewriteMode
    public let sourceApp: String
    public let original: String
    public var result: String

    public init(id: UUID = UUID(), createdAt: Date = Date(), mode: RewriteMode, sourceApp: String, original: String, result: String) {
        self.id = id; self.createdAt = createdAt; self.mode = mode
        self.sourceApp = sourceApp; self.original = original; self.result = result
    }
    public var preview: String { result.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
}

@MainActor
public final class RewriteHistory: ObservableObject {
    public static let limit = 80
    public static let menuLimit = 10
    @Published public private(set) var items: [HistoryItem] = []
    @Published public private(set) var storageError: String?
    public var recentItems: [HistoryItem] { Array(items.prefix(Self.menuLimit)) }
    private let fileURL: URL
    private var canPersist = true

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Polish", isDirectory: true).appendingPathComponent("history.json")
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        do {
            let loaded = try JSONDecoder().decode([HistoryItem].self, from: Data(contentsOf: self.fileURL))
            items = Array(loaded.sorted { $0.createdAt > $1.createdAt }.prefix(Self.limit))
        } catch {
            canPersist = false
            storageError = "Saved history couldn’t be loaded. The existing file has been preserved. New items will stay in this session until you clear history."
        }
    }

    @discardableResult
    public func record(mode: RewriteMode, sourceApp: String, original: String, result: String) -> UUID {
        let item = HistoryItem(mode: mode, sourceApp: sourceApp, original: original, result: result)
        items.insert(item, at: 0)
        items = Array(items.prefix(Self.limit))
        persist()
        return item.id
    }

    public func updateResult(id: UUID, result: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].result != result else { return }
        items[index].result = result
        persist()
    }

    public func clear() {
        // Only called by the user's explicit Clear History action.
        let previousItems = items
        let previousCanPersist = canPersist
        items = []; canPersist = true
        if !persist() { items = previousItems; canPersist = previousCanPersist }
    }

    @discardableResult
    private func persist() -> Bool {
        guard canPersist else { return false }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            storageError = nil
            return true
        } catch {
            storageError = "History couldn’t be saved to this Mac. Your items are available for this session; check available storage and folder access."
            return false
        }
    }
}
