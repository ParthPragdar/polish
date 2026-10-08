import Foundation

/// Word-level differences between an original passage and its rewrite, for highlighting edits.
public enum WordDiff {
    public enum Change: Equatable, Sendable {
        case same(String), removed(String), added(String)
    }

    /// Returns nil when either text has more than `limit` tokens; the comparison is quadratic.
    public static func changes(from old: String, to new: String, limit: Int = 1500) -> [Change]? {
        let a = tokens(old), b = tokens(new)
        guard a.count <= limit, b.count <= limit else { return nil }
        // lcs[i][j] is the longest common subsequence of a[i...] and b[j...], stored flat.
        let width = b.count + 1
        var lcs = [Int32](repeating: 0, count: (a.count + 1) * width)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                lcs[i * width + j] = a[i] == b[j]
                    ? lcs[(i + 1) * width + j + 1] + 1
                    : max(lcs[(i + 1) * width + j], lcs[i * width + j + 1])
            }
        }
        var result: [Change] = []
        func append(_ change: Change) {
            // Merge runs so each edit reads as one phrase.
            switch (result.last, change) {
            case let (.same(x)?, .same(y)): result[result.count - 1] = .same(x + y)
            case let (.removed(x)?, .removed(y)): result[result.count - 1] = .removed(x + y)
            case let (.added(x)?, .added(y)): result[result.count - 1] = .added(x + y)
            default: result.append(change)
            }
        }
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] {
                append(.same(a[i])); i += 1; j += 1
            } else if j == b.count || (i < a.count && lcs[(i + 1) * width + j] >= lcs[i * width + j + 1]) {
                append(.removed(a[i])); i += 1 // Deletions come before insertions within an edit.
            } else {
                append(.added(b[j])); j += 1
            }
        }
        return result
    }

    /// Alternating runs of non-whitespace and whitespace, so spacing survives the round trip.
    static func tokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsSpace: Bool?
        for character in text {
            let isSpace = character.isWhitespace
            if isSpace != currentIsSpace, !current.isEmpty { tokens.append(current); current = "" }
            current.append(character); currentIsSpace = isSpace
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
