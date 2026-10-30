import Foundation

public enum VetoModelError: Error, Equatable {
    case modelNotFound
    case modelLoadFailed(String)
    case inputMismatch(String)
    case inferenceFailed(String)
    case unexpectedOutput(String)
}

/// Runs the neural network. Implemented by `CoreMLVetoModel`; tests substitute stubs.
public protocol VetoModel: Sendable {
    /// Returns the raw model output for the given tensors (the exported graph already applies the sigmoid).
    func predict(_ input: TokenizedInput) throws -> Double
}
