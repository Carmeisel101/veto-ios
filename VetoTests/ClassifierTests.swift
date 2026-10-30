import XCTest
@testable import VetoCore

private struct StubModel: VetoModel {
    var result: Result<Double, VetoModelError>
    func predict(_ input: TokenizedInput) throws -> Double { try result.get() }
}

final class ClassifierTests: XCTestCase {
    private func classifier(_ result: Result<Double, VetoModelError>, threshold: Double = 0.87) throws -> VetoClassifier {
        let tokenizer = try makeTokenizer()
        let metadata = VetoMetadata(modelVersion: "t", threshold: threshold)
        return VetoClassifier(metadata: metadata, tokenizer: tokenizer, model: StubModel(result: result))
    }

    func testThresholdIsInclusive() {
        XCTAssertTrue(VetoPrediction(probability: 0.87, threshold: 0.87).isPoliticalSolicitation)
        XCTAssertFalse(VetoPrediction(probability: 0.8699, threshold: 0.87).isPoliticalSolicitation)
        XCTAssertFalse(VetoPrediction(probability: 0.6, threshold: 0.87).isPoliticalSolicitation, "must not use 0.5")
    }

    func testExportedThresholdIsUsed() async throws {
        let prediction = try await classifier(.success(0.9), threshold: 0.95).classify(text: "x")
        XCTAssertEqual(prediction.threshold, 0.95)
        XCTAssertFalse(prediction.isPoliticalSolicitation)
        let high = try await classifier(.success(0.97), threshold: 0.95).classify(text: "x")
        XCTAssertTrue(high.isPoliticalSolicitation)
    }

    func testShouldFilterFailsOpenOnModelError() throws {
        let failing = try classifier(.failure(.inferenceFailed("boom")))
        XCTAssertFalse(failing.shouldFilter("anything"))
        XCTAssertThrowsError(try failing.classifySync("anything"))
        XCTAssertFalse(try classifier(.failure(.unexpectedOutput("nan"))).shouldFilter("x"))
        XCTAssertTrue(try classifier(.success(0.99)).shouldFilter("x"))
    }

    func testLoadFailsWhenResourcesMissingInsteadOfCrashing() {
        XCTAssertThrowsError(try VetoClassifier.load(from: Bundle(for: TestBundleToken.self).bundle(named: "NoSuchBundle")))
    }

    func testMissingModelUnavailableBundleThrows() {
        let empty = Bundle(path: NSTemporaryDirectory()) ?? .main
        XCTAssertThrowsError(try VetoClassifier.load(from: empty))
    }
}

private extension Bundle {
    func bundle(named name: String) -> Bundle { Bundle(path: bundlePath + "/" + name) ?? Bundle(path: NSTemporaryDirectory())! }
}
