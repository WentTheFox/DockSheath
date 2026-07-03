import Foundation

/// A parsed JSON5 value tree, independent of any specific Swift `Decodable`
/// type — the config layer converts this to plain Foundation types and
/// re-serializes it as standard JSON so `JSONDecoder` can do the typed
/// decoding into `TaskbarConfig`.
public indirect enum JSON5Value: Equatable {
    case object([String: JSON5Value])
    case array([JSON5Value])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    /// Converts to plain Foundation types (`String`, `Int`/`Double`, `Bool`,
    /// `[String: Any]`, `[Any]`, `NSNull`) suitable for
    /// `JSONSerialization.data(withJSONObject:)`.
    public func toFoundation() -> Any {
        switch self {
        case .object(let members):
            var result: [String: Any] = [:]
            result.reserveCapacity(members.count)
            for (key, value) in members {
                result[key] = value.toFoundation()
            }
            return result
        case .array(let elements):
            return elements.map { $0.toFoundation() }
        case .string(let value):
            return value
        case .number(let value):
            // Whole numbers decode as Int where possible so Codable
            // properties typed as Int (e.g. schemaVersion) work directly.
            if value.isFinite, value.truncatingRemainder(dividingBy: 1) == 0, abs(value) < 1e15 {
                return Int(value)
            }
            return value
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        }
    }
}

/// Errors surfaced while parsing a JSON5 document.
public enum JSON5Error: Error, CustomStringConvertible, Equatable {
    case unexpectedCharacter(Character, line: Int, column: Int)
    case unexpectedEndOfInput(line: Int, column: Int)
    case invalidNumber(String, line: Int, column: Int)
    case invalidEscapeSequence(String, line: Int, column: Int)
    case expected(String, found: String, line: Int, column: Int)
    case unterminatedString(line: Int, column: Int)
    case unterminatedComment(line: Int, column: Int)

    public var description: String {
        switch self {
        case .unexpectedCharacter(let character, let line, let column):
            return "Unexpected character '\(character)' at line \(line), column \(column)"
        case .unexpectedEndOfInput(let line, let column):
            return "Unexpected end of input at line \(line), column \(column)"
        case .invalidNumber(let text, let line, let column):
            return "Invalid number '\(text)' at line \(line), column \(column)"
        case .invalidEscapeSequence(let text, let line, let column):
            return "Invalid escape sequence '\(text)' at line \(line), column \(column)"
        case .expected(let expected, let found, let line, let column):
            return "Expected \(expected) but found '\(found)' at line \(line), column \(column)"
        case .unterminatedString(let line, let column):
            return "Unterminated string starting at line \(line), column \(column)"
        case .unterminatedComment(let line, let column):
            return "Unterminated block comment starting at line \(line), column \(column)"
        }
    }
}

/// A hand-written recursive-descent parser for the full JSON5 spec
/// (https://spec.json5.org): `//` and `/* */` comments, trailing commas,
/// single- or double-quoted strings with escaped line continuations,
/// unquoted (identifier) object keys, and extended number syntax (hex,
/// leading/trailing decimal point, explicit `+`, `Infinity`/`NaN`).
public enum JSON5Parser {
    public static func parse(_ text: String) throws -> JSON5Value {
        var lexer = Lexer(text: text)
        let value = try parseValue(&lexer)
        try lexer.skipWhitespaceAndComments()
        guard lexer.isAtEnd else {
            throw JSON5Error.unexpectedCharacter(lexer.currentCharacter!, line: lexer.line, column: lexer.column)
        }
        return value
    }

    private static func parseValue(_ lexer: inout Lexer) throws -> JSON5Value {
        let token = try lexer.nextToken()
        switch token {
        case .leftBrace:
            return try parseObject(&lexer)
        case .leftBracket:
            return try parseArray(&lexer)
        case .string(let value):
            return .string(value)
        case .number(let value):
            return .number(value)
        case .identifier(let name):
            switch name {
            case "true": return .bool(true)
            case "false": return .bool(false)
            case "null": return .null
            case "Infinity": return .number(.infinity)
            case "NaN": return .number(.nan)
            default:
                throw JSON5Error.expected("a value", found: name, line: lexer.tokenLine, column: lexer.tokenColumn)
            }
        default:
            throw JSON5Error.expected("a value", found: token.debugText, line: lexer.tokenLine, column: lexer.tokenColumn)
        }
    }

    private static func parseObject(_ lexer: inout Lexer) throws -> JSON5Value {
        var members: [String: JSON5Value] = [:]

        if try lexer.peekToken() == .rightBrace {
            _ = try lexer.nextToken()
            return .object(members)
        }

        while true {
            let keyToken = try lexer.nextToken()
            let key: String
            switch keyToken {
            case .string(let value):
                key = value
            case .identifier(let value):
                key = value
            default:
                throw JSON5Error.expected("an object key", found: keyToken.debugText, line: lexer.tokenLine, column: lexer.tokenColumn)
            }

            let colon = try lexer.nextToken()
            guard colon == .colon else {
                throw JSON5Error.expected("':'", found: colon.debugText, line: lexer.tokenLine, column: lexer.tokenColumn)
            }

            members[key] = try parseValue(&lexer)

            let separator = try lexer.nextToken()
            if separator == .rightBrace {
                break
            }
            guard separator == .comma else {
                throw JSON5Error.expected("',' or '}'", found: separator.debugText, line: lexer.tokenLine, column: lexer.tokenColumn)
            }
            if try lexer.peekToken() == .rightBrace {
                _ = try lexer.nextToken()
                break
            }
        }

        return .object(members)
    }

    private static func parseArray(_ lexer: inout Lexer) throws -> JSON5Value {
        var elements: [JSON5Value] = []

        if try lexer.peekToken() == .rightBracket {
            _ = try lexer.nextToken()
            return .array(elements)
        }

        while true {
            elements.append(try parseValue(&lexer))

            let separator = try lexer.nextToken()
            if separator == .rightBracket {
                break
            }
            guard separator == .comma else {
                throw JSON5Error.expected("',' or ']'", found: separator.debugText, line: lexer.tokenLine, column: lexer.tokenColumn)
            }
            if try lexer.peekToken() == .rightBracket {
                _ = try lexer.nextToken()
                break
            }
        }

        return .array(elements)
    }
}

/// Lexical tokens of the JSON5 grammar.
enum Token: Equatable {
    case leftBrace, rightBrace, leftBracket, rightBracket, colon, comma
    case identifier(String)
    case string(String)
    case number(Double)

    var debugText: String {
        switch self {
        case .leftBrace: return "{"
        case .rightBrace: return "}"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .colon: return ":"
        case .comma: return ","
        case .identifier(let value): return value
        case .string(let value): return "\"\(value)\""
        case .number(let value): return "\(value)"
        }
    }
}

/// Character-level lexer feeding tokens to `JSON5Parser`. One token of
/// lookahead is supported (needed to detect empty objects/arrays and
/// trailing commas without unconsuming a token).
struct Lexer {
    private let chars: [Character]
    private var index = 0
    var line = 1
    var column = 1
    private(set) var tokenLine = 1
    private(set) var tokenColumn = 1
    private var peeked: Token?

    init(text: String) {
        chars = Array(text)
    }

    var isAtEnd: Bool { index >= chars.count }
    var currentCharacter: Character? { isAtEnd ? nil : chars[index] }

    mutating func nextToken() throws -> Token {
        if let peeked {
            self.peeked = nil
            return peeked
        }
        return try lex()
    }

    mutating func peekToken() throws -> Token {
        if let peeked { return peeked }
        let token = try lex()
        peeked = token
        return token
    }

    @discardableResult
    private mutating func advance() -> Character {
        let character = chars[index]
        index += 1
        if character == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return character
    }

    private func peekCharacter(offset: Int = 0) -> Character? {
        let target = index + offset
        return target < chars.count ? chars[target] : nil
    }

    mutating func skipWhitespaceAndComments() throws {
        while let character = currentCharacter {
            if character.isWhitespace {
                advance()
            } else if character == "/" && peekCharacter(offset: 1) == "/" {
                advance()
                advance()
                while let next = currentCharacter, next != "\n" {
                    advance()
                }
            } else if character == "/" && peekCharacter(offset: 1) == "*" {
                let startLine = line
                let startColumn = column
                advance()
                advance()
                var closed = false
                while let next = currentCharacter {
                    if next == "*" && peekCharacter(offset: 1) == "/" {
                        advance()
                        advance()
                        closed = true
                        break
                    }
                    advance()
                }
                guard closed else {
                    throw JSON5Error.unterminatedComment(line: startLine, column: startColumn)
                }
            } else {
                break
            }
        }
    }

    private mutating func lex() throws -> Token {
        try skipWhitespaceAndComments()
        tokenLine = line
        tokenColumn = column

        guard let character = currentCharacter else {
            throw JSON5Error.unexpectedEndOfInput(line: line, column: column)
        }

        switch character {
        case "{": advance(); return .leftBrace
        case "}": advance(); return .rightBrace
        case "[": advance(); return .leftBracket
        case "]": advance(); return .rightBracket
        case ":": advance(); return .colon
        case ",": advance(); return .comma
        case "\"", "'":
            return .string(try lexString(quote: character))
        default:
            if character == "+" || character == "-" || character == "." || character.isNumber {
                return try lexNumber()
            }
            if character.isLetter || character == "_" || character == "$" {
                return .identifier(lexIdentifier())
            }
            throw JSON5Error.unexpectedCharacter(character, line: line, column: column)
        }
    }

    private mutating func lexIdentifier() -> String {
        var result = ""
        while let character = currentCharacter, character.isLetter || character.isNumber || character == "_" || character == "$" {
            result.append(advance())
        }
        return result
    }

    private mutating func lexString(quote: Character) throws -> String {
        let startLine = line
        let startColumn = column
        advance() // opening quote
        var result = ""

        while true {
            guard let character = currentCharacter else {
                throw JSON5Error.unterminatedString(line: startLine, column: startColumn)
            }
            if character == quote {
                advance()
                return result
            }
            if character == "\n" {
                // Unescaped newlines aren't allowed inside JSON5 strings —
                // only escaped line continuations (`\` + newline) are.
                throw JSON5Error.unterminatedString(line: startLine, column: startColumn)
            }
            if character == "\\" {
                advance()
                guard let escaped = currentCharacter else {
                    throw JSON5Error.unterminatedString(line: startLine, column: startColumn)
                }
                switch escaped {
                case "\n":
                    advance() // line continuation: contributes nothing to the string
                case "\r":
                    advance()
                    if currentCharacter == "\n" { advance() } // \r\n continuation
                case "'": advance(); result.append("'")
                case "\"": advance(); result.append("\"")
                case "\\": advance(); result.append("\\")
                case "b": advance(); result.append("\u{08}")
                case "f": advance(); result.append("\u{0C}")
                case "n": advance(); result.append("\n")
                case "r": advance(); result.append("\r")
                case "t": advance(); result.append("\t")
                case "v": advance(); result.append("\u{0B}")
                case "0": advance(); result.append("\u{00}")
                case "x":
                    advance()
                    let hex = try lexFixedHex(count: 2)
                    guard let scalarValue = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(scalarValue) else {
                        throw JSON5Error.invalidEscapeSequence("\\x\(hex)", line: line, column: column)
                    }
                    result.append(Character(scalar))
                case "u":
                    advance()
                    let hex = try lexFixedHex(count: 4)
                    guard let scalarValue = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(scalarValue) else {
                        throw JSON5Error.invalidEscapeSequence("\\u\(hex)", line: line, column: column)
                    }
                    result.append(Character(scalar))
                default:
                    // JSON5 permits any other character to be escaped literally.
                    advance()
                    result.append(escaped)
                }
            } else {
                result.append(advance())
            }
        }
    }

    private mutating func lexFixedHex(count: Int) throws -> String {
        var hex = ""
        for _ in 0..<count {
            guard let character = currentCharacter, character.isHexDigit else {
                throw JSON5Error.invalidEscapeSequence(hex, line: line, column: column)
            }
            hex.append(advance())
        }
        return hex
    }

    private mutating func lexNumber() throws -> Token {
        let startLine = line
        let startColumn = column
        var text = ""
        var isNegative = false

        if currentCharacter == "+" || currentCharacter == "-" {
            isNegative = currentCharacter == "-"
            text.append(advance())
        }

        if let identifier = peekIdentifierAhead(), identifier == "Infinity" || identifier == "NaN" {
            _ = lexIdentifier()
            let magnitude: Double = identifier == "Infinity" ? .infinity : .nan
            return .number(isNegative ? -magnitude : magnitude)
        }

        if currentCharacter == "0", peekCharacter(offset: 1) == "x" || peekCharacter(offset: 1) == "X" {
            text.append(advance()) // 0
            text.append(advance()) // x / X
            var hexDigits = ""
            while let character = currentCharacter, character.isHexDigit {
                hexDigits.append(advance())
            }
            guard !hexDigits.isEmpty, let value = UInt64(hexDigits, radix: 16) else {
                throw JSON5Error.invalidNumber(text + hexDigits, line: startLine, column: startColumn)
            }
            let magnitude = Double(value)
            return .number(isNegative ? -magnitude : magnitude)
        }

        var hasDigits = false
        while let character = currentCharacter, character.isNumber {
            text.append(advance())
            hasDigits = true
        }
        if currentCharacter == "." {
            text.append(advance())
            while let character = currentCharacter, character.isNumber {
                text.append(advance())
                hasDigits = true
            }
        }
        guard hasDigits else {
            throw JSON5Error.invalidNumber(text, line: startLine, column: startColumn)
        }
        if currentCharacter == "e" || currentCharacter == "E" {
            text.append(advance())
            if currentCharacter == "+" || currentCharacter == "-" {
                text.append(advance())
            }
            var hasExponentDigits = false
            while let character = currentCharacter, character.isNumber {
                text.append(advance())
                hasExponentDigits = true
            }
            guard hasExponentDigits else {
                throw JSON5Error.invalidNumber(text, line: startLine, column: startColumn)
            }
        }

        guard let value = Double(text) else {
            throw JSON5Error.invalidNumber(text, line: startLine, column: startColumn)
        }
        return .number(value)
    }

    /// Looks ahead (without consuming) for a run of letters, used to detect
    /// `Infinity`/`NaN` immediately following a `+`/`-` sign.
    private func peekIdentifierAhead() -> String? {
        var offset = 0
        var result = ""
        while let character = peekCharacter(offset: offset), character.isLetter {
            result.append(character)
            offset += 1
        }
        return result.isEmpty ? nil : result
    }
}
