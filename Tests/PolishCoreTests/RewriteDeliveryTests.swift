import XCTest
@testable import PolishCore

@MainActor
final class RewriteDeliveryTests: XCTestCase {
    private enum Failure: Error { case draftChanged }

    func testAutoApplyCompletesWithoutRequestingReview() async throws {
        var applications = 0
        let outcome = try await RewriteDelivery.deliver(automatically: true) { applications += 1 }
        guard case .applied = outcome else { return XCTFail("Automatic mode must not request confirmation") }
        XCTAssertEqual(applications, 1)
    }
    func testReviewModeNeverChangesTheDraftBeforeConfirmation() async throws {
        var applications = 0
        let outcome = try await RewriteDelivery.deliver(automatically: false) { applications += 1 }
        guard case .review = outcome else { return XCTFail("Review mode must request confirmation") }
        XCTAssertEqual(applications, 0)
    }
    func testAutomaticApplyFailureDoesNotFallBackToReview() async throws {
        let outcome = try await RewriteDelivery.deliver(automatically: true) { throw Failure.draftChanged }
        guard case .automaticFailure(let error) = outcome, error is Failure else {
            return XCTFail("A changed draft must report automatic failure, not open the review editor")
        }
    }
    func testCancellationDoesNotBecomeAnErrorPopup() async {
        do {
            _ = try await RewriteDelivery.deliver(automatically: true) { throw CancellationError() }
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
        catch { XCTFail("Unexpected error: \(error)") }
    }
}
