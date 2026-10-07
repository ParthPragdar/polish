import XCTest
@testable import PolishCore

@MainActor
final class FocusLookupTests: XCTestCase {
    func testWaitsForDelayedElectronFocus() async throws {
        var probes = 0
        let found = try await FocusLookup.resolve(attempts: 5, delay: .milliseconds(1), isCurrent: { true }) {
            probes += 1
            return probes == 4 ? "editor" : nil
        }
        XCTAssertEqual(found, "editor")
        XCTAssertEqual(probes, 4)
    }

    func testDoesNotReadAnApplicationAfterFocusChanges() async {
        var probes = 0
        do {
            let _: String? = try await FocusLookup.resolve(attempts: 5, delay: .milliseconds(1), isCurrent: { probes < 1 }) {
                probes += 1
                return nil
            }
            XCTFail("A changed application must abort the lookup")
        } catch FocusLookupError.applicationChanged {
            XCTAssertEqual(probes, 1)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testUnavailableEditorStopsAfterBoundedRetries() async throws {
        var probes = 0
        let found: String? = try await FocusLookup.resolve(attempts: 3, delay: .milliseconds(1), isCurrent: { true }) {
            probes += 1
            return nil
        }
        XCTAssertNil(found)
        XCTAssertEqual(probes, 3)
    }

    func testCancellationDoesNotReturnOrReadText() async {
        var probes = 0
        let task = Task { @MainActor in
            try await FocusLookup.resolve(attempts: 5, delay: .milliseconds(1), isCurrent: { true }) {
                probes += 1
                return "editor"
            }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { XCTAssertEqual(probes, 0) }
        catch { XCTFail("Unexpected error: \(error)") }
    }
}
