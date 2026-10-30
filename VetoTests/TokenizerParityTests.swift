import XCTest
@testable import VetoCore

/// Exactness is the contract: ids and masks must equal Python's, element for element.
final class TokenizerParityTests: XCTestCase {
    func testGoldenTokenizationParity() throws {
        let tokenizer = try makeTokenizer()
        let file = try JSONDecoder().decode(TokenFixtureFile.self, from: fixtureData("golden_tokenization"))
        XCTAssertEqual(file.examples.count, 70)
        for (index, example) in file.examples.enumerated() {
            let encoded = tokenizer.encode(example.text)
            let expectedIDs = example.input_ids + Array(repeating: 0, count: 256 - example.input_ids.count)
            let expectedMask = Array(repeating: Int32(1), count: example.input_ids.count)
                + Array(repeating: Int32(0), count: 256 - example.input_ids.count)
            XCTAssertEqual(encoded.inputIDs, expectedIDs, "input_ids mismatch for golden example \(index)")
            XCTAssertEqual(encoded.attentionMask, expectedMask, "attention_mask mismatch for golden example \(index)")
        }
    }

    func testEdgeCaseParity() throws {
        let tokenizer = try makeTokenizer()
        let file = try JSONDecoder().decode(TokenFixtureFile.self, from: fixtureData("edge_tokenization"))
        XCTAssertGreaterThanOrEqual(file.examples.count, 30)
        for example in file.examples {
            XCTAssertEqual(unpadded(tokenizer.encode(example.text)), example.input_ids, "edge case \(example.name ?? "?")")
        }
    }
}
