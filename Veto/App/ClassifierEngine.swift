import Foundation
import Observation
import VetoCore

/// Owns the shared `VetoClassifier` for the SwiftUI app and records local-only timings.
@MainActor @Observable
final class ClassifierEngine {
    enum State { case idle, loading, ready, failed(String) }

    private(set) var state: State = .idle
    private(set) var metadata: VetoMetadata?
    private(set) var loadMilliseconds: Double?
    private(set) var lastPrediction: VetoPrediction?
    private(set) var lastTimings: VetoTimings?
    private(set) var firstInferenceMilliseconds: Double?
    private(set) var errorMessage: String?
    private var classifier: VetoClassifier?

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        state = .loading
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let loaded = try await Task.detached(priority: .userInitiated) { try VetoClassifier.load() }.value
            let elapsed = clock.now - start
            loadMilliseconds = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
            classifier = loaded
            metadata = loaded.metadata
            state = .ready
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    func classify(_ text: String) async {
        guard let classifier else { return }
        errorMessage = nil
        do {
            let (prediction, timings) = try await classifier.classifyTimed(text: text)
            if firstInferenceMilliseconds == nil { firstInferenceMilliseconds = timings.totalMilliseconds }
            lastPrediction = prediction
            lastTimings = timings
        } catch {
            lastPrediction = nil
            errorMessage = Self.describe(error)
        }
    }

    private static func describe(_ error: Error) -> String {
        if case VetoClassifierError.resourceMissing(let name) = error {
            return "\(name) is missing from the build. Import your Veto export with scripts/import-veto-model.sh and rebuild."
        }
        return String(describing: error)
    }
}
