import Foundation

public enum VetoMetadataError: Error, Equatable {
    case unreadable
    case invalid(String)
}

/// The deployment contract exported by Veto (`metadata.json`). Only values the runtime needs
/// are decoded; unknown keys are ignored so additive export changes do not break the app.
public struct VetoMetadata: Decodable, Sendable, Equatable {
    public let modelName: String
    public let modelVersion: String
    public let baseModel: String
    public let modelType: String
    public let threshold: Double
    public let positiveLabel: String
    public let negativeLabel: String
    public let maxSequenceLength: Int
    public let inputNames: [String]
    public let outputNames: [String]
    public let minimumDeploymentTarget: String?
    public let tokenizer: TokenizerSettings

    public struct TokenizerSettings: Decodable, Sendable, Equatable {
        public let type: String
        public let vocabSize: Int?
        public let lowercase: Bool
        public let stripAccents: Bool?
        public let cleanText: Bool
        public let handleChineseChars: Bool
        public let unknownToken: String
        public let specialTokens: [String: Int]

        // WordPiece details that metadata does not carry; fixed by the BERT WordPiece family.
        public var padToken: String { "[PAD]" }
        public var clsToken: String { "[CLS]" }
        public var sepToken: String { "[SEP]" }
        public var continuingSubwordPrefix: String { "##" }
        public var maxInputCharsPerWord: Int { 100 }

        enum CodingKeys: String, CodingKey {
            case type, lowercase
            case specialTokens = "special_tokens"
            case vocabSize = "vocab_size", stripAccents = "strip_accents", cleanText = "clean_text"
            case handleChineseChars = "handle_chinese_chars", unknownToken = "unknown_token"
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            vocabSize = try c.decodeIfPresent(Int.self, forKey: .vocabSize)
            lowercase = try c.decode(Bool.self, forKey: .lowercase)
            stripAccents = try c.decodeIfPresent(Bool.self, forKey: .stripAccents)
            cleanText = try c.decode(Bool.self, forKey: .cleanText)
            handleChineseChars = try c.decode(Bool.self, forKey: .handleChineseChars)
            unknownToken = try c.decode(String.self, forKey: .unknownToken)
            specialTokens = try c.decode([String: Int].self, forKey: .specialTokens)
        }
        public init(type: String = "BertTokenizer (WordPiece)", vocabSize: Int? = nil, lowercase: Bool = true,
                    stripAccents: Bool? = nil, cleanText: Bool = true, handleChineseChars: Bool = true,
                    unknownToken: String = "[UNK]", specialTokens: [String: Int] = [:]) {
            self.type = type; self.vocabSize = vocabSize; self.lowercase = lowercase
            self.stripAccents = stripAccents; self.cleanText = cleanText
            self.handleChineseChars = handleChineseChars; self.unknownToken = unknownToken
            self.specialTokens = specialTokens
        }
    }

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name", modelVersion = "model_version", baseModel = "base_model"
        case modelType = "model_type", threshold, positiveLabel = "positive_label"
        case negativeLabel = "negative_label", maxSequenceLength = "max_sequence_length"
        case inputNames = "input_names", outputNames = "output_names"
        case minimumDeploymentTarget = "minimum_deployment_target", tokenizer
    }

    public init(modelName: String = "veto", modelVersion: String, baseModel: String = "test", modelType: String = "test",
                threshold: Double, positiveLabel: String = "political_solicitation",
                negativeLabel: String = "not_political_solicitation", maxSequenceLength: Int = 256,
                inputNames: [String] = ["input_ids", "attention_mask"],
                outputNames: [String] = ["political_solicitation_probability"],
                minimumDeploymentTarget: String? = nil, tokenizer: TokenizerSettings = .init()) {
        self.modelName = modelName; self.modelVersion = modelVersion; self.baseModel = baseModel
        self.modelType = modelType; self.threshold = threshold; self.positiveLabel = positiveLabel
        self.negativeLabel = negativeLabel; self.maxSequenceLength = maxSequenceLength
        self.inputNames = inputNames; self.outputNames = outputNames
        self.minimumDeploymentTarget = minimumDeploymentTarget; self.tokenizer = tokenizer
    }

    public static func parse(_ data: Data) throws -> VetoMetadata {
        let metadata: VetoMetadata
        do { metadata = try JSONDecoder().decode(VetoMetadata.self, from: data) }
        catch { throw VetoMetadataError.invalid("decoding failed: \(error)") }
        try metadata.validate()
        return metadata
    }

    func validate() throws {
        guard threshold > 0, threshold <= 1 else { throw VetoMetadataError.invalid("threshold out of (0, 1]") }
        guard maxSequenceLength >= 2 else { throw VetoMetadataError.invalid("max_sequence_length") }
        guard inputNames.count == 2, outputNames.count == 1 else {
            throw VetoMetadataError.invalid("expected 2 inputs and 1 output")
        }
        guard tokenizer.type.contains("WordPiece") else {
            throw VetoMetadataError.invalid("unsupported tokenizer \(tokenizer.type)")
        }
    }
}
