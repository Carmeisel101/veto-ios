import XCTest
@testable import VetoCore

/// Local integration tests: need the private model (`scripts/import-veto-model.sh`) and the
/// Python reference (`scripts/make-python-reference.py`). Skipped when absent.
final class ModelParityTests: XCTestCase {
    struct Reference: Decodable { let text: String; let probability: Double; let should_filter: Bool; let category: String }
    struct ReferenceFile: Decodable { let threshold: Double; let examples: [Reference] }

    private func loadClassifier() throws -> VetoClassifier {
        do { return try VetoClassifier.load() }
        catch VetoClassifierError.resourceMissing(let name) {
            throw XCTSkip("\(name) not bundled; import a Veto export to run model integration tests")
        }
    }

    func testModelLoadsAndMatchesExportedContract() throws {
        let classifier = try loadClassifier()
        XCTAssertEqual(classifier.metadata.maxSequenceLength, 256)
        XCTAssertEqual(classifier.tokenizer.vocabularySize, classifier.metadata.tokenizer.vocabSize)
        let (prediction, _) = try classifier.classifySync("Reply STOP to end")
        XCTAssertTrue((0...1).contains(prediction.probability))
        XCTAssertEqual(prediction.threshold, classifier.metadata.threshold)
    }

    func testCoreMLMatchesPythonProbabilitiesAndDecisions() throws {
        let classifier = try loadClassifier()
        guard let url = testBundle.url(forResource: "python_reference", withExtension: "json") else {
            throw XCTSkip("python_reference.json absent; run scripts/make-python-reference.py")
        }
        let reference = try JSONDecoder().decode(ReferenceFile.self, from: Data(contentsOf: url))
        XCTAssertEqual(classifier.metadata.threshold, reference.threshold, accuracy: 1e-12)
        var maxDiff = 0.0, disagreements: [String] = []
        for (i, example) in reference.examples.enumerated() {
            let (prediction, _) = try classifier.classifySync(example.text)
            maxDiff = max(maxDiff, abs(prediction.probability - example.probability))
            if prediction.isPoliticalSolicitation != example.should_filter {
                disagreements.append("#\(i) \(example.category): swift \(prediction.probability) python \(example.probability)")
            }
        }
        print("VETO_PARITY examples=\(reference.examples.count) maxAbsDiff=\(maxDiff) disagreements=\(disagreements.count)")
        XCTAssertLessThanOrEqual(maxDiff, 0.01, "FP16 tolerance from export contract")
        XCTAssertTrue(disagreements.isEmpty, "decision disagreements: \(disagreements)")
    }

    func testWarmInferenceLatencyIsReported() throws {
        let classifier = try loadClassifier()
        _ = try classifier.classifySync("warm up")
        var times: [Double] = []
        for _ in 0..<30 { times.append(try classifier.classifySync("Vote early this November, reply STOP to end").1.totalMilliseconds) }
        times.sort()
        print("VETO_LATENCY simulator warm median=\(times[15])ms p95=\(times[28])ms (not device performance)")
    }
}
