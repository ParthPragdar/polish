import Foundation

/// Only confirmation mode can request a review panel. An automatic failure remains
/// an automatic failure; it must never silently turn into a confirmation workflow.
@MainActor
public enum RewriteDelivery {
    public enum Outcome {
        case review
        case applied
        case automaticFailure(Error)
    }
    public static func deliver(automatically: Bool, apply: () async throws -> Void) async throws -> Outcome {
        try Task.checkCancellation()
        guard automatically else { return .review }
        do {
            try await apply()
            return .applied
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .automaticFailure(error)
        }
    }
}
