import Foundation

/// Errors surfaced while preprocessing a restricted-JSON5 document into
/// standard JSON that `JSONDecoder` can parse.
public enum JSON5Error: Error, CustomStringConvertible, Equatable {
    case unterminatedString(line: Int, column: Int)
    case unterminatedBlockComment(line: Int, column: Int)

    public var description: String {
        switch self {
        case .unterminatedString(let line, let column):
            return "Unterminated string literal starting at line \(line), column \(column)"
        case .unterminatedBlockComment(let line, let column):
            return "Unterminated block comment starting at line \(line), column \(column)"
        }
    }
}

/// Converts a deliberately restricted subset of JSON5 — standard JSON plus
/// `//` line comments, `/* */` block comments, and trailing commas before
/// `}`/`]` — into standard JSON text.
///
/// This intentionally does NOT support the rest of the JSON5 spec (unquoted
/// keys, single-quoted strings, etc.) to keep the tokenizer simple and its
/// interaction with `JSONDecoder` predictable.
public enum JSON5Preprocessor {
    public static func preprocess(_ input: String) throws -> String {
        let withoutComments = try stripComments(input)
        return removeTrailingCommas(withoutComments)
    }

    static func stripComments(_ input: String) throws -> String {
        enum State { case normal, inString, inLineComment, inBlockComment }

        var state = State.normal
        let chars = Array(input)
        var output = String()
        output.reserveCapacity(chars.count)

        var i = 0
        var line = 1
        var column = 1
        var escapeNext = false
        var stringStart = (line: 1, column: 1)
        var blockCommentStart = (line: 1, column: 1)

        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil

            switch state {
            case .normal:
                if c == "\"" {
                    state = .inString
                    stringStart = (line, column)
                    output.append(c)
                } else if c == "/" && next == "/" {
                    state = .inLineComment
                    i += 1
                    column += 1
                } else if c == "/" && next == "*" {
                    state = .inBlockComment
                    blockCommentStart = (line, column)
                    output.append(" ")
                    i += 1
                    column += 1
                    output.append(" ")
                } else {
                    output.append(c)
                }
            case .inString:
                output.append(c)
                if escapeNext {
                    escapeNext = false
                } else if c == "\\" {
                    escapeNext = true
                } else if c == "\"" {
                    state = .normal
                }
            case .inLineComment:
                if c == "\n" {
                    state = .normal
                    output.append(c)
                } else {
                    output.append(" ")
                }
            case .inBlockComment:
                if c == "*" && next == "/" {
                    state = .normal
                    output.append(" ")
                    i += 1
                    column += 1
                    output.append(" ")
                } else if c == "\n" {
                    output.append(c)
                } else {
                    output.append(" ")
                }
            }

            if c == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            i += 1
        }

        if state == .inString {
            throw JSON5Error.unterminatedString(line: stringStart.line, column: stringStart.column)
        }
        if state == .inBlockComment {
            throw JSON5Error.unterminatedBlockComment(line: blockCommentStart.line, column: blockCommentStart.column)
        }

        return output
    }

    static func removeTrailingCommas(_ input: String) -> String {
        enum State { case normal, inString }

        var state = State.normal
        let chars = Array(input)
        var output = [Character]()
        output.reserveCapacity(chars.count)
        var escapeNext = false
        var i = 0

        while i < chars.count {
            let c = chars[i]
            switch state {
            case .normal:
                if c == "\"" {
                    state = .inString
                    output.append(c)
                } else if c == "," {
                    var j = i + 1
                    while j < chars.count, chars[j].isJSONWhitespace {
                        j += 1
                    }
                    if j < chars.count, chars[j] == "}" || chars[j] == "]" {
                        output.append(" ")
                    } else {
                        output.append(c)
                    }
                } else {
                    output.append(c)
                }
            case .inString:
                output.append(c)
                if escapeNext {
                    escapeNext = false
                } else if c == "\\" {
                    escapeNext = true
                } else if c == "\"" {
                    state = .normal
                }
            }
            i += 1
        }

        return String(output)
    }
}

private extension Character {
    var isJSONWhitespace: Bool {
        self == " " || self == "\t" || self == "\n" || self == "\r"
    }
}
