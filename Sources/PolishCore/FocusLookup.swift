import Foundation

public enum FocusLookupError: Error { case applicationChanged }

/// Accessibility trees can arrive asynchronously after Chromium/Electron enables them.
/// Never continue probing if the user switches to another application.
@MainActor
public enum FocusLookup {
    public static func resolve<Value>(
        attempts: Int = 9,
        delay: Duration = .milliseconds(120),
        isCurrent: () -> Bool,
        probe: () -> Value?
    ) async throws -> Value? {
        for attempt in 0..<max(attempts, 1) {
            try Task.checkCancellation()
            guard isCurrent() else { throw FocusLookupError.applicationChanged }
            if let value = probe() { return value }
            if attempt + 1 < attempts { try await Task.sleep(for: delay) }
        }
        return nil
    }
}
