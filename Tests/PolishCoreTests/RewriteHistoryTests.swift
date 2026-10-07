import XCTest
@testable import PolishCore

@MainActor
final class RewriteHistoryTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("polish-history-tests-" + UUID().uuidString, isDirectory: true)
            .appendingPathComponent("history.json")
    }
    func testKeepsNewest80AndMenuNewest10AcrossRestart() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let history = RewriteHistory(fileURL: url)
        for index in 0..<85 {
            history.record(mode: index.isMultiple(of: 2) ? .grammar : .prompt, sourceApp: "Test", original: "draft \(index)", result: "result \(index)")
        }
        XCTAssertEqual(history.items.count, 80)
        XCTAssertEqual(history.items.first?.result, "result 84")
        XCTAssertEqual(history.items.last?.result, "result 5")
        XCTAssertEqual(history.recentItems.map(\.result), (75...84).reversed().map { "result \($0)" })
        let restored = RewriteHistory(fileURL: url)
        XCTAssertEqual(restored.items, history.items)
        XCTAssertNil(restored.storageError)
    }
    func testEditedResultUpdatesSameEntryAndPreservesOriginalMetadata() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let history = RewriteHistory(fileURL: url)
        let id = history.record(mode: .prompt, sourceApp: "Chrome", original: "नमस्ते 👩🏽‍💻\nOriginal", result: "First result")
        let first = try XCTUnwrap(history.items.first)
        history.record(mode: .grammar, sourceApp: "TextEdit", original: "Other", result: "Other result")
        history.updateResult(id: id, result: "Edited\n\n- Keep `code` intact.")
        let restored = RewriteHistory(fileURL: url)
        XCTAssertEqual(restored.items.count, 2)
        let edited = try XCTUnwrap(restored.items.last)
        XCTAssertEqual(edited.id, first.id)
        XCTAssertEqual(edited.createdAt, first.createdAt)
        XCTAssertEqual(edited.original, first.original)
        XCTAssertEqual(edited.sourceApp, "Chrome")
        XCTAssertEqual(edited.mode, .prompt)
        XCTAssertEqual(edited.result, "Edited\n\n- Keep `code` intact.")
    }
    func testClearPersistsAcrossRestart() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let history = RewriteHistory(fileURL: url)
        history.record(mode: .grammar, sourceApp: "Test", original: "Old", result: "Saved")
        history.clear()
        XCTAssertTrue(history.items.isEmpty)
        XCTAssertTrue(RewriteHistory(fileURL: url).items.isEmpty)
    }
    func testMalformedFileIsPreservedUntilExplicitClear() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let malformed = Data("incomplete json".utf8)
        try malformed.write(to: url)
        let history = RewriteHistory(fileURL: url)
        XCTAssertNotNil(history.storageError)
        history.record(mode: .grammar, sourceApp: "Test", original: "New", result: "Result")
        XCTAssertEqual(try Data(contentsOf: url), malformed)
        history.clear()
        XCTAssertNil(history.storageError)
        XCTAssertTrue(RewriteHistory(fileURL: url).items.isEmpty)
    }
    func testWriteFailureRetainsSessionHistoryAndReportsIt() async throws {
        let parent = location().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try Data("This is a file, not a folder".utf8).write(to: parent)
        let history = RewriteHistory(fileURL: parent.appendingPathComponent("history.json"))
        history.record(mode: .grammar, sourceApp: "Test", original: "Original", result: "Result")
        XCTAssertEqual(history.items.count, 1)
        XCTAssertNotNil(history.storageError)
        history.clear()
        XCTAssertEqual(history.items.count, 1, "A failed clear must not pretend the history was removed")
    }
    func testSavedFileIsPrivateAndMenuPreviewNormalizesWhitespace() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let history = RewriteHistory(fileURL: url)
        history.record(mode: .grammar, sourceApp: "Test", original: "Original", result: "  Hello\n\nworld.  ")
        XCTAssertEqual(history.recentItems.first?.preview, "Hello world.")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
}
