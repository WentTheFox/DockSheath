import Foundation

/// A small hand-rolled fuzzy matcher for the quick-launch search field —
/// deliberately not a third-party dependency, consistent with keeping this
/// project's dependency surface minimal.
public enum FuzzySearch {
    /// Returns a match score (higher is better), or nil if `query` isn't a
    /// subsequence of `candidate`. Prefix and word-boundary matches score
    /// higher than scattered subsequence matches.
    public static func score(query: String, candidate: String) -> Int? {
        guard !query.isEmpty else { return 0 }

        let queryChars = Array(query.lowercased())
        let candidateChars = Array(candidate.lowercased())
        guard !candidateChars.isEmpty else { return nil }

        if candidate.lowercased().hasPrefix(query.lowercased()) {
            return 1000 - candidateChars.count
        }

        var score = 0
        var queryIndex = 0
        var previousMatchIndex = -1

        for (candidateIndex, character) in candidateChars.enumerated() {
            guard queryIndex < queryChars.count else { break }
            guard character == queryChars[queryIndex] else { continue }

            if candidateIndex == previousMatchIndex + 1 {
                score += 15
            } else if candidateIndex == 0 || candidateChars[candidateIndex - 1] == " " {
                score += 10
            } else {
                score += 1
            }

            previousMatchIndex = candidateIndex
            queryIndex += 1
        }

        guard queryIndex == queryChars.count else { return nil }
        return score
    }

    public static func filterAndSort<T>(
        _ items: [T],
        query: String,
        text: (T) -> String
    ) -> [T] {
        guard !query.isEmpty else { return items }

        let scored: [(item: T, score: Int)] = items.compactMap { item in
            guard let score = score(query: query, candidate: text(item)) else { return nil }
            return (item, score)
        }
        return scored.sorted { $0.score > $1.score }.map(\.item)
    }
}
