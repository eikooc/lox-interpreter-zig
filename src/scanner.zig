const std = @import("std");
const tokens = @import("./token-type.zig");
const Token = tokens.Token;
const Allocator = std.mem.Allocator;

const Sizes = @import("./helper-types.zig");
pub const Scanner = struct {
    const Self = @This();

    allocator: Allocator,
    token_list: std.ArrayList(Token),

    source: []const u8,
    start: Sizes.MaxCharacters = 0,
    current: Sizes.MaxCharacters = 0,
    line: Sizes.MaxLines = 1,

    hadError: bool = false,

    pub fn init(self: *Scanner, source: []const u8) Scanner {
        const allocator = std.heap.page_allocator;
        const token_list = std.ArrayList(Token).init(allocator);
        self.token_list = token_list;
        self.source = source;
        return self;
    }

    fn isAtEnd(self: *Scanner) bool {
        return self.current >= (self.source.len - 1);
    }

    pub fn scanTokens(self: *Scanner) !std.ArrayList(Token) {
        while (!isAtEnd(self)) {
            try scanToken(self);
        }

        const token = Token{
            .type = tokens.TokenType.EOF,
            .lexeme = "",
            .literal = null,
            .line = self.line,
        };

        try self.token_list.append(token);
        return self.token_list;
    }

    pub fn scanToken(self: *Scanner) !void {
        const c = advance(self);

        switch (c) {
            // Whitespace characters should be ignored
            ' ' => {},
            '\r' => {},
            '\t' => {},
            '\n' => self.line += 1,
            // One character tokens
            '(' => try addToken(self, tokens.TokenType.LEFT_PAREN, null),
            ')' => try addToken(self, tokens.TokenType.RIGHT_PAREN, null),
            '{' => try addToken(self, tokens.TokenType.LEFT_BRACE, null),
            '}' => try addToken(self, tokens.TokenType.RIGHT_BRACE, null),
            ',' => try addToken(self, tokens.TokenType.COMMA, null),
            '.' => try addToken(self, tokens.TokenType.DOT, null),
            '-' => try addToken(self, tokens.TokenType.MINUS, null),
            '+' => try addToken(self, tokens.TokenType.PLUS, null),
            ';' => try addToken(self, tokens.TokenType.SEMICOLON, null),
            '*' => try addToken(self, tokens.TokenType.STAR, null),
            // Two-character tokens
            '!' => try addToken(self, if (match(self, '=')) tokens.TokenType.BANG_EQUAL else tokens.TokenType.BANG, null),
            '=' => try addToken(self, if (match(self, '=')) tokens.TokenType.EQUAL_EQUAL else tokens.TokenType.EQUAL, null),
            '<' => try addToken(self, if (match(self, '=')) tokens.TokenType.LESS_EQUAL else tokens.TokenType.LESS, null),
            '>' => try addToken(self, if (match(self, '=')) tokens.TokenType.GREATER_EQUAL else tokens.TokenType.GREATER, null),
            '/' => if (match(self, '/')) {
                // A comment goes until the end of the line
                while (peek(self) != '\n' and !self.isAtEnd()) {
                    _ = advance(self);
                }
                // This is not part of the book,
                // but without it we get wrong line number reporting.
                self.line += 1;
            } else {
                try addToken(self, tokens.TokenType.SLASH, null);
            },
            // Literals
            '"' => try string(self),
            // Reserved keywords and identifiers
            '0'...'9' => try number(self),
            'a'...'z' => try identifier(self),
            'A'...'Z' => try identifier(self),
            '_' => try identifier(self),
            // When nothing matches, add to error map.
            else => {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Unexpected Character: {c}",
                    .{c},
                );
                try self.presentError(self.line, msg);
            },
        }

        self.start = self.current;
    }

    fn isAlpha(char: u8) bool {
        const is_special_char = (char == '_');
        return std.ascii.isAlphabetic(char) or is_special_char;
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    fn identifier(self: *Scanner) !void {
        while (isAlphaNumeric(peek(self))) {
            _ = advance(self);
        }

        const text = self.source[self.start..self.current];
        const token_type = keywords(text);
        try addToken(self, token_type, null);
    }

    fn isDigit(c: ?u8) bool {
        if (c) |not_null_c| {
            return not_null_c >= '0' and not_null_c <= '9';
        }

        return false;
    }

    fn number(self: *Scanner) !void {
        while (isDigit(peek(self))) {
            _ = advance(self);
        }

        // Look for a fraction
        if (peek(self) == '.' and isDigit(peekNext(self))) {
            _ = advance(self);

            while (isDigit(peek(self))) {
                _ = advance(self);
            }
        }

        try addToken(self, tokens.TokenType.NUMBER, self.source[self.start..self.current]);
    }

    fn string(self: *Scanner) !void {
        while (peek(self) != '"' and !isAtEnd(self)) {
            if (peek(self) == '\n') {
                self.line += 1;
            }
            _ = advance(self);
        }

        if (isAtEnd(self)) {
            try presentError(self, self.line, "Unterminated string");
            return;
        }

        // Close out the string by advancing.
        _ = advance(self);

        const value = self.source[(self.start + 1)..(self.current - 1)];

        try addToken(self, tokens.TokenType.STRING, value);
    }

    fn peekNext(self: *Scanner) ?u8 {
        if (self.current + 1 >= self.source.len) return null;
        return self.source[self.current + 1];
    }

    fn peek(self: *Scanner) u8 {
        if (isAtEnd(self)) return '\n'; // TODO: In the book he returns \0. Why?
        return self.source[self.current];
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (isAtEnd(self)) return false;
        if (self.source[self.current] != expected) return false;

        self.current += 1;
        return true;
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: *Scanner, token_type: tokens.TokenType, literal: ?[]const u8) !void {
        const sub = self.source[self.start..self.current];
        const token = Token{
            .type = token_type,
            .lexeme = sub,
            .literal = literal,
            .line = self.line,
        };
        try self.token_list.append(token);
    }

    fn presentError(self: *Self, line: Sizes.MaxLines, message: []const u8) !void {
        try report(line, "", message);
        self.hadError = true;
    }
};

fn report(line: Sizes.MaxLines, where: []const u8, message: []const u8) !void {
    std.debug.print("[line {!d}] Error {!s}: {!s}\n", .{ line, where, message });
}

const Keywords = enum {
    @"and",
    class,
    @"else",
    false,
    @"for",
    fun,
    @"if",
    nil,
    @"or",
    print,
    @"return",
    super,
    this,
    true,
    @"var",
    @"while",
};

fn keywords(str: []const u8) tokens.TokenType {
    const enummed = std.meta.stringToEnum(Keywords, str);
    if (enummed == null) {
        return tokens.TokenType.IDENTIFIER;
    }
    const tokenType: tokens.TokenType = switch (enummed.?) {
        .@"and" => tokens.TokenType.AND,
        .class => tokens.TokenType.CLASS,
        .@"else" => tokens.TokenType.ELSE,
        .false => tokens.TokenType.FALSE,
        .@"for" => tokens.TokenType.FOR,
        .fun => tokens.TokenType.FUN,
        .@"if" => tokens.TokenType.IF,
        .nil => tokens.TokenType.NIL,
        .@"or" => tokens.TokenType.OR,
        .print => tokens.TokenType.PRINT,
        .@"return" => tokens.TokenType.RETURN,
        .super => tokens.TokenType.SUPER,
        .this => tokens.TokenType.THIS,
        .true => tokens.TokenType.TRUE,
        .@"var" => tokens.TokenType.VAR,
        .@"while" => tokens.TokenType.WHILE,
    };
    return tokenType;
}
