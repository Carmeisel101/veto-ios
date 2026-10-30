import Foundation

/// Greedy longest-match-first WordPiece segmentation over a fixed vocabulary.
struct WordPieceTokenizer: Sendable {
    let vocabulary: [String: Int32]
    let unknownID: Int32
    let continuationPrefix: String
    let maxInputCharsPerWord: Int

    /// Segments one pre-token into vocabulary IDs. A word that cannot be fully segmented
    /// (or is too long) becomes a single unknown token.
    func tokenize(_ word: [Unicode.Scalar]) -> [Int32] {
        guard word.count <= maxInputCharsPerWord else { return [unknownID] }
        var ids: [Int32] = []
        var start = 0
        while start < word.count {
            var end = word.count
            var matched: Int32?
            while start < end {
                var piece = String(String.UnicodeScalarView(word[start..<end]))
                if start > 0 { piece = continuationPrefix + piece }
                if let id = vocabulary[piece] { matched = id; break }
                end -= 1
            }
            guard let id = matched else { return [unknownID] }
            ids.append(id)
            start = end
        }
        return ids
    }
}
