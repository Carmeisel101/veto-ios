import XCTest
@testable import VetoCore

final class TokenizerUnitTests: XCTestCase {
    func testVocabularyLoadingAndSpecialTokens() throws {
        let tokenizer = try makeTokenizer()
        XCTAssertEqual(tokenizer.vocabularySize, 30522)
        XCTAssertEqual(tokenizer.padID, 0)
        XCTAssertEqual(tokenizer.unknownID, 100)
        XCTAssertEqual(tokenizer.clsID, 101)
        XCTAssertEqual(tokenizer.sepID, 102)
    }

    func testVocabularySizeMismatchIsRejected() throws {
        let settings = VetoMetadata.TokenizerSettings(vocabSize: 5)
        XCTAssertThrowsError(try VetoTokenizer(vocabularyText: "[PAD]\n[UNK]\n[CLS]\n[SEP]\n", settings: settings, maxSequenceLength: 8))
    }

    func testMissingSpecialTokenIsRejected() {
        XCTAssertThrowsError(try VetoTokenizer(vocabularyText: "hello\nworld\n", settings: .init(), maxSequenceLength: 8))
    }

    func testEmptyInputIsClsSepAndPadding() throws {
        let encoded = try makeTokenizer().encode("")
        XCTAssertEqual(Array(encoded.inputIDs.prefix(3)), [101, 102, 0])
        XCTAssertEqual(Array(encoded.attentionMask.prefix(3)), [1, 1, 0])
        XCTAssertEqual(encoded.inputIDs.count, 256)
        XCTAssertEqual(encoded.length, 2)
    }

    func testTruncationKeepsSepWithinBudget() throws {
        let encoded = try makeTokenizer().encode(String(repeating: "vote ", count: 1000))
        XCTAssertEqual(encoded.length, 256)
        XCTAssertEqual(encoded.inputIDs.first, 101)
        XCTAssertEqual(encoded.inputIDs.last, 102)
        XCTAssertFalse(encoded.attentionMask.contains(0))
    }

    func testCaseAndAccentFolding() throws {
        let t = try makeTokenizer()
        XCTAssertEqual(t.encode("Café NAÏVE"), t.encode("cafe naive"))
    }

    func testPunctuationIsSplit() throws {
        let t = try makeTokenizer()
        XCTAssertEqual(unpadded(t.encode("hello,world")), unpadded(t.encode("hello , world")))
    }

    func testUnknownWordBecomesSingleUnk() throws {
        let t = try makeTokenizer()
        XCTAssertEqual(unpadded(t.encode("hello😀world")), [101, 100, 102])
        XCTAssertEqual(unpadded(t.encode(String(repeating: "a", count: 101))), [101, 100, 102])
    }

    func testWordPieceSegmentsSubwords() throws {
        let ids = unpadded(try makeTokenizer().encode("unsubscribe"))
        XCTAssertGreaterThan(ids.count, 3, "expected subword pieces plus CLS/SEP")
        XCTAssertFalse(ids.contains(100))
    }

    func testAttentionMaskMatchesPadding() throws {
        let encoded = try makeTokenizer().encode("Vote early")
        for (id, mask) in zip(encoded.inputIDs, encoded.attentionMask) where mask == 0 { XCTAssertEqual(id, 0) }
        XCTAssertEqual(encoded.attentionMask.prefix(encoded.length).reduce(0, +), Int32(encoded.length))
    }

    func testMetadataParsing() throws {
        let metadata = try VetoMetadata.parse(fixtureData("synthetic_metadata"))
        XCTAssertEqual(metadata.modelVersion, "test-1")
        XCTAssertEqual(metadata.threshold, 0.8)
        XCTAssertEqual(metadata.maxSequenceLength, 256)
        XCTAssertEqual(metadata.inputNames, ["input_ids", "attention_mask"])
        XCTAssertEqual(metadata.tokenizer.specialTokens["[CLS]"], 101)
        XCTAssertNil(metadata.tokenizer.stripAccents)
    }

    func testMetadataRejectsBadThreshold() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData("synthetic_metadata")) as? [String: Any])
        json["threshold"] = 1.5
        XCTAssertThrowsError(try VetoMetadata.parse(JSONSerialization.data(withJSONObject: json)))
        json["threshold"] = 0.5
        json["input_names"] = ["only_one"]
        XCTAssertThrowsError(try VetoMetadata.parse(JSONSerialization.data(withJSONObject: json)))
        XCTAssertThrowsError(try VetoMetadata.parse(Data("not json".utf8)))
    }
}
