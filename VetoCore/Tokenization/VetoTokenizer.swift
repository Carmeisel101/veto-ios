import Foundation

/// Model-ready tensors for one message, padded to the model's fixed sequence length.
public struct TokenizedInput: Equatable, Sendable {
    public let inputIDs: [Int32]
    public let attentionMask: [Int32]
    /// Number of real (non-padding) tokens, including `[CLS]` and `[SEP]`.
    public var length: Int { attentionMask.reduce(0) { $0 + Int($1) } }
}

public enum VetoTokenizerError: Error, Equatable {
    case vocabularyMissing
    case vocabularyInvalid(String)
}

/// BERT WordPiece tokenizer reproducing the Hugging Face tokenizer Veto exported:
/// `[CLS] tokens [SEP]`, right truncation (special tokens inside the budget), right padding.
public struct VetoTokenizer: Sendable {
    public let maxSequenceLength: Int
    public let padID: Int32
    public let clsID: Int32
    public let sepID: Int32
    public let unknownID: Int32
    public var vocabularySize: Int { wordPiece.vocabulary.count }

    private let basic: BasicTokenizer
    private let wordPiece: WordPieceTokenizer

    /// - Parameters:
    ///   - vocabulary: one token per line; line index is the token ID.
    ///   - settings: tokenizer behaviour read from the exported metadata.
    public init(vocabularyText: String, settings: VetoMetadata.TokenizerSettings, maxSequenceLength: Int) throws {
        var vocabulary: [String: Int32] = [:]
        // Split at byte level on "\n": Swift treats "\r\n" as a single Character.
        var lines = vocabularyText.utf8.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
        if lines.last?.isEmpty == true { lines.removeLast() }
        for (index, line) in lines.enumerated() {
            var token = String(decoding: line, as: UTF8.self)
            while let last = token.unicodeScalars.last, last.properties.isWhitespace { token.unicodeScalars.removeLast() }
            // A repeated token (or one canonically equivalent to an earlier token, which Swift
            // String equality cannot distinguish) keeps its first ID; the vocabulary-size
            // check below makes such a collision visible.
            if vocabulary[token] == nil { vocabulary[token] = Int32(index) }
        }
        guard !vocabulary.isEmpty else { throw VetoTokenizerError.vocabularyMissing }

        func id(_ token: String) throws -> Int32 {
            guard let id = vocabulary[token] else { throw VetoTokenizerError.vocabularyInvalid("missing \(token)") }
            return id
        }
        padID = try id(settings.padToken)
        clsID = try id(settings.clsToken)
        sepID = try id(settings.sepToken)
        unknownID = try id(settings.unknownToken)
        if let expected = settings.vocabSize, expected != vocabulary.count {
            throw VetoTokenizerError.vocabularyInvalid("expected \(expected) tokens, found \(vocabulary.count)")
        }
        guard maxSequenceLength >= 2 else { throw VetoTokenizerError.vocabularyInvalid("maxSequenceLength") }
        self.maxSequenceLength = maxSequenceLength
        basic = BasicTokenizer(lowercase: settings.lowercase,
                               stripAccents: settings.stripAccents ?? settings.lowercase,
                               cleanText: settings.cleanText,
                               handleChineseChars: settings.handleChineseChars)
        wordPiece = WordPieceTokenizer(vocabulary: vocabulary, unknownID: unknownID,
                                       continuationPrefix: settings.continuingSubwordPrefix,
                                       maxInputCharsPerWord: settings.maxInputCharsPerWord)
    }

    public func encode(_ text: String) -> TokenizedInput {
        var ids: [Int32] = []
        for word in basic.tokenize(text) {
            ids.append(contentsOf: wordPiece.tokenize(word))
            if ids.count >= maxSequenceLength - 2 { break }
        }
        if ids.count > maxSequenceLength - 2 { ids.removeLast(ids.count - (maxSequenceLength - 2)) }
        let real = [clsID] + ids + [sepID]
        let padding = maxSequenceLength - real.count
        return TokenizedInput(
            inputIDs: real + Array(repeating: padID, count: padding),
            attentionMask: Array(repeating: 1, count: real.count) + Array(repeating: 0, count: padding))
    }
}
