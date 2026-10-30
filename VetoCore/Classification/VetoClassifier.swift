import Foundation
import os

public enum VetoClassifierError: Error {
    case resourceMissing(String)
    case metadata(VetoMetadataError)
    case tokenizer(VetoTokenizerError)
    case model(VetoModelError)
}

/// Application-facing classifier: tokenizer + Core ML model + exported threshold.
/// No Core ML types leak through this interface.
public final class VetoClassifier: Sendable {
    public let metadata: VetoMetadata
    public let tokenizer: VetoTokenizer
    private let model: any VetoModel

    public init(metadata: VetoMetadata, tokenizer: VetoTokenizer, model: any VetoModel) {
        self.metadata = metadata; self.tokenizer = tokenizer; self.model = model
    }

    /// Loads metadata, vocabulary and the compiled model from a bundle (the VetoCore framework
    /// bundle by default). Throws if anything is missing; callers must treat that as "do not filter".
    public static func load(from bundle: Bundle = .vetoCore, computeUnits: MLComputeUnitsOption = .all) throws -> VetoClassifier {
        guard let metadataURL = bundle.url(forResource: "metadata", withExtension: "json") else {
            throw VetoClassifierError.resourceMissing("metadata.json")
        }
        guard let vocabURL = bundle.url(forResource: "vocab", withExtension: "txt") else {
            throw VetoClassifierError.resourceMissing("vocab.txt")
        }
        guard let modelURL = bundle.url(forResource: "veto", withExtension: "mlmodelc") else {
            throw VetoClassifierError.resourceMissing("veto.mlmodelc")
        }
        return try load(metadataURL: metadataURL, vocabularyURL: vocabURL, compiledModelURL: modelURL, computeUnits: computeUnits)
    }

    public static func load(metadataURL: URL, vocabularyURL: URL, compiledModelURL: URL,
                            computeUnits: MLComputeUnitsOption = .all) throws -> VetoClassifier {
        do {
            let metadata = try VetoMetadata.parse(Data(contentsOf: metadataURL))
            let vocabulary = try String(contentsOf: vocabularyURL, encoding: .utf8)
            let tokenizer = try VetoTokenizer(vocabularyText: vocabulary, settings: metadata.tokenizer,
                                              maxSequenceLength: metadata.maxSequenceLength)
            let model = try CoreMLVetoModel(compiledModelURL: compiledModelURL, metadata: metadata,
                                            computeUnits: computeUnits.mlValue)
            return VetoClassifier(metadata: metadata, tokenizer: tokenizer, model: model)
        } catch let error as VetoMetadataError { throw VetoClassifierError.metadata(error) }
        catch let error as VetoTokenizerError { throw VetoClassifierError.tokenizer(error) }
        catch let error as VetoModelError { throw VetoClassifierError.model(error) }
    }

    /// Synchronous classification, safe to call from any thread. Throws on any runtime failure.
    public func classifySync(_ text: String) throws -> (VetoPrediction, VetoTimings) {
        let clock = ContinuousClock()
        let start = clock.now
        let input = tokenizer.encode(text)
        let tokenized = clock.now
        let probability = try model.predict(input)
        let end = clock.now
        let prediction = VetoPrediction(probability: probability, threshold: metadata.threshold)
        return (prediction, VetoTimings(tokenizeMilliseconds: (tokenized - start).milliseconds,
                                        inferenceMilliseconds: (end - tokenized).milliseconds))
    }

    public func classify(text: String) async throws -> VetoPrediction {
        try await classifyTimed(text: text).0
    }

    /// Runs off the caller's actor so SwiftUI is never blocked by inference.
    public func classifyTimed(text: String) async throws -> (VetoPrediction, VetoTimings) {
        try await Task.detached(priority: .userInitiated) { [self] in try classifySync(text) }.value
    }

    /// Fail-open decision: `true` only when classification succeeded AND crossed the threshold.
    /// Any error yields `false`. Logs error kind only, never message text.
    public func shouldFilter(_ text: String) -> Bool {
        do { return try classifySync(text).0.isPoliticalSolicitation }
        catch {
            Logger(subsystem: "veto", category: "classifier").error("classification failed; failing open: \(String(describing: type(of: error)), privacy: .public)")
            return false
        }
    }
}

public enum MLComputeUnitsOption: Sendable { case all, cpuOnly, cpuAndNeuralEngine }

private extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}

private final class BundleToken {}
public extension Bundle {
    /// The bundle holding VetoCore's resources (the framework bundle).
    static var vetoCore: Bundle { Bundle(for: BundleToken.self) }
}
