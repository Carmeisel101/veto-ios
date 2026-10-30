import Foundation

/// BERT "basic tokenization": text cleaning, CJK isolation, accent stripping, lowercasing and
/// whitespace/punctuation splitting. Mirrors the Hugging Face `BertNormalizer` + `BertPreTokenizer`
/// that produced Veto's golden fixtures.
struct BasicTokenizer: Sendable {
    var lowercase: Bool
    var stripAccents: Bool
    var cleanText: Bool
    var handleChineseChars: Bool

    /// Normalizes `text` and splits it into pre-tokens (words and standalone punctuation).
    func tokenize(_ text: String) -> [[Unicode.Scalar]] {
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            if cleanText {
                if scalar.value == 0 || scalar.value == 0xFFFD || Self.isControl(scalar) { continue }
                if scalar.properties.isWhitespace { scalars.append(" "); continue }
            }
            if handleChineseChars && Self.isChineseChar(scalar) {
                scalars.append(" "); scalars.append(scalar); scalars.append(" ")
            } else {
                scalars.append(scalar)
            }
        }

        var normalized = scalars
        if stripAccents {
            // NFD, then drop nonspacing marks.
            var view = String.UnicodeScalarView()
            view.append(contentsOf: normalized)
            let decomposed = String(view).decomposedStringWithCanonicalMapping
            normalized = decomposed.unicodeScalars.filter { $0.properties.generalCategory != .nonspacingMark }
        }
        if lowercase {
            normalized = normalized.flatMap { Array($0.properties.lowercaseMapping.unicodeScalars) }
        }
        return Self.splitWordsAndPunctuation(normalized)
    }

    private static func splitWordsAndPunctuation(_ scalars: [Unicode.Scalar]) -> [[Unicode.Scalar]] {
        var tokens: [[Unicode.Scalar]] = []
        var current: [Unicode.Scalar] = []
        func flush() { if !current.isEmpty { tokens.append(current); current = [] } }
        for scalar in scalars {
            if scalar.properties.isWhitespace {
                flush()
            } else if isPunctuation(scalar) {
                flush()
                tokens.append([scalar])
            } else {
                current.append(scalar)
            }
        }
        flush()
        return tokens
    }

    /// Control, format, surrogate, private-use and unassigned characters, except tab/newline/CR.
    static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "\t" || scalar == "\n" || scalar == "\r" { return false }
        switch scalar.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned: return true
        default: return false
        }
    }

    /// BERT punctuation: every ASCII non-alphanumeric printable character, plus Unicode `P*`.
    static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        if (33...47).contains(v) || (58...64).contains(v) || (91...96).contains(v) || (123...126).contains(v) {
            return true
        }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    static func isChineseChar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F,
             0x2B740...0x2B81F, 0x2B820...0x2CEAF, 0xF900...0xFAFF, 0x2F800...0x2FA1F:
            return true
        default:
            return false
        }
    }
}
