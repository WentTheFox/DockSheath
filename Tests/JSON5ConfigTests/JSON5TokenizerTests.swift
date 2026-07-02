import XCTest
@testable import JSON5Config

final class JSON5TokenizerTests: XCTestCase {
    func testStripsLineComments() throws {
        let input = """
        {
          "a": 1, // trailing line comment
          // a full-line comment
          "b": 2
        }
        """
        let result = try JSON5Preprocessor.stripComments(input)
        XCTAssertFalse(result.contains("//"))
        XCTAssertTrue(result.contains("\"a\": 1"))
        XCTAssertTrue(result.contains("\"b\": 2"))
    }

    func testStripsBlockComments() throws {
        let input = "{ \"a\": /* inline */ 1, \"b\": 2 /* trailing\nmultiline */ }"
        let result = try JSON5Preprocessor.stripComments(input)
        XCTAssertFalse(result.contains("/*"))
        XCTAssertFalse(result.contains("*/"))
        XCTAssertTrue(result.contains("\"a\":"))
        XCTAssertTrue(result.contains("1,"))
    }

    func testDoesNotStripCommentLikeTextInsideStrings() throws {
        let input = #"{ "url": "https://example.com", "note": "/* not a comment */" }"#
        let result = try JSON5Preprocessor.stripComments(input)
        XCTAssertTrue(result.contains("https://example.com"))
        XCTAssertTrue(result.contains("/* not a comment */"))
    }

    func testUnterminatedStringThrows() {
        let input = #"{ "a": "unterminated }"#
        XCTAssertThrowsError(try JSON5Preprocessor.stripComments(input)) { error in
            guard case JSON5Error.unterminatedString = error else {
                return XCTFail("Expected unterminatedString, got \(error)")
            }
        }
    }

    func testUnterminatedBlockCommentThrows() {
        let input = "{ \"a\": 1 /* never closed"
        XCTAssertThrowsError(try JSON5Preprocessor.stripComments(input)) { error in
            guard case JSON5Error.unterminatedBlockComment = error else {
                return XCTFail("Expected unterminatedBlockComment, got \(error)")
            }
        }
    }

    func testRemovesTrailingCommaBeforeClosingBrace() {
        let input = #"{ "a": 1, "b": 2, }"#
        let result = JSON5Preprocessor.removeTrailingCommas(input)
        XCTAssertEqual(try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Int], ["a": 1, "b": 2])
    }

    func testRemovesTrailingCommaBeforeClosingBracket() {
        let input = "[1, 2, 3, ]"
        let result = JSON5Preprocessor.removeTrailingCommas(input)
        XCTAssertEqual(try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [Int], [1, 2, 3])
    }

    func testDoesNotTouchCommasInsideStrings() {
        let input = #"{ "a": "one, two, three" }"#
        let result = JSON5Preprocessor.removeTrailingCommas(input)
        XCTAssertEqual(result, input)
    }

    func testDoesNotStripTrailingCommaAcrossNewlinesAndWhitespace() {
        let input = "{\n  \"a\": 1,\n}\n"
        let result = JSON5Preprocessor.removeTrailingCommas(input)
        let obj = try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Int]
        XCTAssertEqual(obj, ["a": 1])
    }

    func testFullPreprocessRoundTrip() throws {
        let input = """
        {
          // pinned apps
          "schemaVersion": 1,
          "pinnedApps": [
            { "bundlePath": "/Applications/Safari.app", }, // trailing comma + comment
          ],
        }
        """
        let jsonText = try JSON5Preprocessor.preprocess(input)
        let data = Data(jsonText.utf8)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }
}
