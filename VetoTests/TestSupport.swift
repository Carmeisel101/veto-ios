import Foundation
import XCTest
@testable import VetoCore

final class TestBundleToken {}
let testBundle = Bundle(for: TestBundleToken.self)

func fixtureData(_ name: String, _ ext: String = "json") throws -> Data {
    let url = try XCTUnwrap(testBundle.url(forResource: name, withExtension: ext), "missing fixture \(name).\(ext)")
    return try Data(contentsOf: url)
}

func makeTokenizer() throws -> VetoTokenizer {
    let metadata = try VetoMetadata.parse(fixtureData("synthetic_metadata"))
    let vocabURL = try XCTUnwrap(Bundle.vetoCore.url(forResource: "vocab", withExtension: "txt"))
    return try VetoTokenizer(vocabularyText: String(contentsOf: vocabURL, encoding: .utf8),
                             settings: metadata.tokenizer, maxSequenceLength: metadata.maxSequenceLength)
}

struct TokenFixture: Decodable { let name: String?; let text: String; let input_ids: [Int32] }
struct TokenFixtureFile: Decodable { let examples: [TokenFixture] }

/// Returns unpadded ids the tokenizer produced (ids up to and including the final [SEP]).
func unpadded(_ input: TokenizedInput) -> [Int32] { Array(input.inputIDs.prefix(input.length)) }
