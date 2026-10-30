import Foundation

/// Result of classifying one message. Contains no message text.
public struct VetoPrediction: Equatable, Sendable {
    /// Probability in [0, 1] that the message is political solicitation.
    public let probability: Double
    /// The exported decision threshold the probability was compared against.
    public let threshold: Double
    /// `probability >= threshold`.
    public let isPoliticalSolicitation: Bool

    public init(probability: Double, threshold: Double) {
        self.probability = probability
        self.threshold = threshold
        self.isPoliticalSolicitation = probability >= threshold
    }
}

/// Local, in-process timings for one classification (development visibility only).
public struct VetoTimings: Equatable, Sendable {
    public var tokenizeMilliseconds: Double
    public var inferenceMilliseconds: Double
    public var totalMilliseconds: Double { tokenizeMilliseconds + inferenceMilliseconds }
}
