import XCTest
@testable import JSON5Config

final class JSON5ParserTests: XCTestCase {
    // MARK: - Comments (still supported)

    func testStripsLineAndBlockComments() throws {
        let text = """
        {
          "a": 1, // trailing line comment
          // a full-line comment
          "b": /* inline */ 2,
        }
        """
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .number(1))
        XCTAssertEqual(members["b"], .number(2))
    }

    func testDoesNotTreatCommentMarkersInsideStringsAsComments() throws {
        let text = #"{ "url": "https://example.com", "note": "/* not a comment */" }"#
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["url"], .string("https://example.com"))
        XCTAssertEqual(members["note"], .string("/* not a comment */"))
    }

    // MARK: - Trailing commas (still supported)

    func testTrailingCommaInObjectAndArray() throws {
        let text = #"{ "a": 1, "list": [1, 2, 3,], }"#
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .number(1))
        XCTAssertEqual(members["list"], .array([.number(1), .number(2), .number(3)]))
    }

    // MARK: - Full JSON5: unquoted keys

    func testUnquotedIdentifierKeys() throws {
        let text = "{ foo: 1, _bar$: 2, camelCase: 3 }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["foo"], .number(1))
        XCTAssertEqual(members["_bar$"], .number(2))
        XCTAssertEqual(members["camelCase"], .number(3))
    }

    func testReservedWordsAllowedAsUnquotedKeys() throws {
        let text = "{ true: 1, null: 2 }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["true"], .number(1))
        XCTAssertEqual(members["null"], .number(2))
    }

    // MARK: - Full JSON5: single-quoted strings

    func testSingleQuotedStrings() throws {
        let text = "{ 'a': 'hello', \"b\": \"world\" }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .string("hello"))
        XCTAssertEqual(members["b"], .string("world"))
    }

    func testStringEscapesAndLineContinuation() throws {
        let text = "{ \"a\": \"line one \\\nstill line one\", \"b\": \"tab:\\there\" }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .string("line one still line one"))
        XCTAssertEqual(members["b"], .string("tab:\there"))
    }

    func testUnicodeAndHexEscapes() throws {
        let text = #"{ "a": "AB", "b": "\x43" }"#
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .string("AB"))
        XCTAssertEqual(members["b"], .string("C"))
    }

    // MARK: - Full JSON5: extended numbers

    func testHexNumbers() throws {
        let text = "{ \"a\": 0xFF, \"b\": -0x10 }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .number(255))
        XCTAssertEqual(members["b"], .number(-16))
    }

    func testLeadingAndTrailingDecimalPoint() throws {
        let text = "{ \"a\": .5, \"b\": 5., \"c\": +3 }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(members["a"], .number(0.5))
        XCTAssertEqual(members["b"], .number(5))
        XCTAssertEqual(members["c"], .number(3))
    }

    func testInfinityAndNaN() throws {
        let text = "{ \"a\": Infinity, \"b\": -Infinity, \"c\": NaN }"
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        guard case .number(let a) = members["a"], case .number(let b) = members["b"], case .number(let c) = members["c"] else {
            return XCTFail("Expected numbers")
        }
        XCTAssertEqual(a, .infinity)
        XCTAssertEqual(b, -.infinity)
        XCTAssertTrue(c.isNaN)
    }

    // MARK: - Nesting

    func testNestedObjectsAndArrays() throws {
        let text = """
        {
          list: [1, { nested: true }, [2, 3]],
        }
        """
        guard case .object(let members) = try JSON5Parser.parse(text) else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(
            members["list"],
            .array([.number(1), .object(["nested": .bool(true)]), .array([.number(2), .number(3)])])
        )
    }

    // MARK: - Errors

    func testUnterminatedStringThrows() {
        let text = #"{ "a": "unterminated }"#
        XCTAssertThrowsError(try JSON5Parser.parse(text)) { error in
            guard case JSON5Error.unterminatedString = error else {
                return XCTFail("Expected unterminatedString, got \(error)")
            }
        }
    }

    func testUnterminatedCommentThrows() {
        let text = "{ \"a\": 1 /* never closed"
        XCTAssertThrowsError(try JSON5Parser.parse(text)) { error in
            guard case JSON5Error.unterminatedComment = error else {
                return XCTFail("Expected unterminatedComment, got \(error)")
            }
        }
    }

    func testMissingColonThrows() {
        let text = "{ \"a\" 1 }"
        XCTAssertThrowsError(try JSON5Parser.parse(text)) { error in
            guard case JSON5Error.expected = error else {
                return XCTFail("Expected .expected error, got \(error)")
            }
        }
    }

    func testInvalidNumberThrows() {
        let text = "{ \"a\": - }"
        XCTAssertThrowsError(try JSON5Parser.parse(text)) { error in
            guard case JSON5Error.invalidNumber = error else {
                return XCTFail("Expected invalidNumber, got \(error)")
            }
        }
    }

    // MARK: - toFoundation()

    func testToFoundationRoundTripsThroughJSONSerialization() throws {
        let text = #"{ name: 'Dock', count: 3, ratio: 1.5, enabled: true, missing: null }"#
        let value = try JSON5Parser.parse(text)
        let foundation = value.toFoundation()
        XCTAssertTrue(JSONSerialization.isValidJSONObject(foundation))
        let data = try JSONSerialization.data(withJSONObject: foundation)
        let roundTripped = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(roundTripped?["name"] as? String, "Dock")
        XCTAssertEqual(roundTripped?["count"] as? Int, 3)
        XCTAssertEqual(roundTripped?["ratio"] as? Double, 1.5)
        XCTAssertEqual(roundTripped?["enabled"] as? Bool, true)
        XCTAssertTrue(roundTripped?["missing"] is NSNull)
    }
}
