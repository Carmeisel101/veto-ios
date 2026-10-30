import CoreML
import Foundation

/// Core ML adapter. Feature names and shapes come from the exported metadata and are checked
/// against the compiled model's description at load time, so a mismatched export fails loudly
/// (and the classifier then fails open) rather than producing silent garbage.
public final class CoreMLVetoModel: VetoModel, @unchecked Sendable {
    private let model: MLModel
    private let idsName: String
    private let maskName: String
    private let outputName: String
    private let length: Int

    /// - Parameter compiledModelURL: URL of a compiled `.mlmodelc`.
    public init(compiledModelURL: URL, metadata: VetoMetadata, computeUnits: MLComputeUnits = .all) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        do { model = try MLModel(contentsOf: compiledModelURL, configuration: configuration) }
        catch { throw VetoModelError.modelLoadFailed(String(describing: error)) }

        idsName = metadata.inputNames[0]
        maskName = metadata.inputNames[1]
        outputName = metadata.outputNames[0]
        length = metadata.maxSequenceLength

        let description = model.modelDescription
        for name in [idsName, maskName] {
            guard let feature = description.inputDescriptionsByName[name],
                  let constraint = feature.multiArrayConstraint,
                  constraint.dataType == .int32,
                  constraint.shape.map(\.intValue) == [1, metadata.maxSequenceLength] else {
                throw VetoModelError.inputMismatch(name)
            }
        }
        guard description.outputDescriptionsByName[outputName] != nil else {
            throw VetoModelError.inputMismatch(outputName)
        }
    }

    /// Compiles an uncompiled `.mlpackage` first (used by tests and the local import workflow).
    public static func compile(packageAt url: URL) throws -> URL {
        do { return try MLModel.compileModel(at: url) }
        catch { throw VetoModelError.modelLoadFailed(String(describing: error)) }
    }

    public func predict(_ input: TokenizedInput) throws -> Double {
        guard input.inputIDs.count == length, input.attentionMask.count == length else {
            throw VetoModelError.inputMismatch("sequence length")
        }
        do {
            let ids = try MLMultiArray(shape: [1, NSNumber(value: length)], dataType: .int32)
            let mask = try MLMultiArray(shape: [1, NSNumber(value: length)], dataType: .int32)
            for i in 0..<length {
                ids[i] = NSNumber(value: input.inputIDs[i])
                mask[i] = NSNumber(value: input.attentionMask[i])
            }
            let features = try MLDictionaryFeatureProvider(dictionary: [idsName: ids, maskName: mask])
            let output = try model.prediction(from: features)
            guard let array = output.featureValue(for: outputName)?.multiArrayValue, array.count == 1 else {
                throw VetoModelError.unexpectedOutput("missing or non-scalar output")
            }
            let value = array[0].doubleValue
            guard value.isFinite, (0...1).contains(value) else {
                throw VetoModelError.unexpectedOutput("not a probability")
            }
            return value
        } catch let error as VetoModelError {
            throw error
        } catch {
            throw VetoModelError.inferenceFailed(String(describing: error))
        }
    }
}
