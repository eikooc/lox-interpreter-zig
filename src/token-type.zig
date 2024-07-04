const std = @import("std");
const Sizes = @import("./helper-types.zig");

pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: ?[]const u8,
    line: Sizes.MaxLines,

    pub fn toString(self: Token, allocator: std.mem.Allocator) std.fmt.AllocPrintError![]u8 {
        return std.fmt.allocPrint(allocator, "{} {s} {?s}", .{ self.type, self.lexeme, self.literal });
    }
};
