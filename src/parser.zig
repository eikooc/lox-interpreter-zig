const std = @import("std");
const tokens = @import("./token-type.zig");
const Token = tokens.Token;
const Sizes = @import("./helper-types.zig");
const Lox = @import("./Lox.zig");
const Allocator = std.mem.Allocator;

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    current: Sizes.MaxCharacters = 0,

    pub fn init(token_list: std.ArrayList(Token)) Parser {
        return Parser{
            .tokens = token_list,
        };
    }

    fn match_1(self: *Parser, token: tokens.TokenType) bool {
        if (self.check(token)) {
            _ = self.advance();
            return true;
        }
        return false;
    }
    fn match_2(self: *Parser, token_1: tokens.TokenType, token_2: tokens.TokenType) bool {
        return self.match_1(token_1) or self.match_1(token_2);
    }

    fn consume(self: *Parser, token_type: tokens.TokenType, message: []const u8) Token {
        if (self.check(token_type)) return advance(self);
        std.debug.print("{} {s}", .{ peek(self), message });
        return advance(self);
        // return error.ParseError;
    }

    fn reportError() error.ParseError {
        std.log.err("Parse Error", .{});
        return error.ParseError;
    }

    fn check(self: *Parser, token_type: tokens.TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == token_type;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.current += 1;
        return self.previous();
    }

    fn isAtEnd(self: *Parser) bool {
        return peek(self).type == tokens.TokenType.EOF;
    }

    fn peek(self: *Parser) Token {
        return self.tokens.items[self.current];
    }

    fn previous(self: *Parser) Token {
        return self.tokens.items[self.current - 1];
    }

    fn synchronize() void {
        _ = advance();

        while (!isAtEnd()) {
            if (previous().type == tokens.TokenType.SEMICOLON) return;
            switch (peek().type) {
                tokens.TokenType.CLASS, tokens.TokenType.FUN, tokens.TokenType.VAR, tokens.TokenType.FOR, tokens.TokenType.IF, tokens.TokenType.WHILE, tokens.TokenType.PRINT, tokens.TokenType.RETURN => {},
            }
        }
        _ = advance();
    }

    fn expression(self: *Parser) Expr {
        return equality(self);
    }

    fn equality(self: *Parser) Expr {
        std.debug.print("Entered equality\n", .{});

        const expr = comparison(self);

        while (self.match_2(tokens.TokenType.BANG_EQUAL, tokens.TokenType.EQUAL_EQUAL)) {
            std.debug.print("Comparison: {}\n", .{self.tokens.items[self.current]});

            const operator: Token = previous(self);
            const right: Expr = comparison(self);
            std.debug.print("Operator: {}\n", .{operator});
            // std.debug.print("Right: {}\n", .{right});

            return .{ .binary = .{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }

        return expr;
    }

    fn comparison(self: *Parser) Expr {
        std.debug.print("Entered comparison: {}\n", .{1});

        const expr = term(self);

        while (self.match_2(tokens.TokenType.GREATER, tokens.TokenType.GREATER_EQUAL) or self.match_2(tokens.TokenType.LESS, tokens.TokenType.LESS_EQUAL)) {
            const operator: Token = previous(self);
            const right: Expr = term(self);
            return .{ .binary = .{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }

        return expr;
    }

    fn term(self: *Parser) Expr {
        std.debug.print("Entered term\n", .{});

        const expr = factor(self);

        while (self.match_2(tokens.TokenType.MINUS, tokens.TokenType.PLUS)) {
            const operator = previous(self);
            const right = factor(self);
            return .{ .binary = .{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }

        return expr;
    }

    fn factor(self: *Parser) Expr {
        std.debug.print("Entered factor\n", .{});
        const expr = unary(self);
        std.debug.print("Returned from unary to factor\n", .{});

        while (self.match_2(tokens.TokenType.SLASH, tokens.TokenType.STAR)) {
            const operator = previous(self);
            const right = factor(self);
            return .{ .binary = .{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }

        return expr;
    }

    fn unary(self: *Parser) Expr {
        std.debug.print("Entered unary\n", .{});
        if (self.match_2(tokens.TokenType.BANG, tokens.TokenType.MINUS)) {
            std.debug.print("Pew Pew: {} {d}\n", .{ self.previous().type, self.previous().line });
            std.debug.print("Current: {d}\n", .{self.current});
            std.debug.print("item: {}\n", .{self.tokens.items[self.current].type});
            std.debug.print("Matched: {d}, {?s}\n", .{ self.peek().line, self.peek().literal });
            std.debug.print("Matched bang or minus: {}\n", .{self.peek().type});
            const operator = previous(self);
            std.debug.print("Prev?: {}\n", .{previous(self).type});
            const right = unary(self);
            std.debug.print("Returning unary\n", .{});
            return .{
                .unary = .{
                    .operator = operator,
                    .right = &right,
                },
            };
        }
        // std.debug.print("No match {}\n", .{self.tokens.items[self.current]});

        return primary(self);
    }

    fn primary(self: *Parser) Expr {
        std.debug.print("Entered primary: {}\n", .{self.tokens.items[self.current]});
        std.debug.print("Entered primary: {s}\n", .{self.peek().lexeme});

        if (self.match_1(tokens.TokenType.FALSE)) return .{ .literal = .{ .boolean = false } };
        if (self.match_1(tokens.TokenType.TRUE)) return .{ .literal = .{ .boolean = true } };
        if (self.match_1(tokens.TokenType.NIL)) return .{ .literal = .{ .nil = null } };

        if (self.match_1(tokens.TokenType.NUMBER)) {
            const prev = previous(self).literal;
            if (prev) |literal| {
                const number = std.fmt.parseFloat(f64, literal) catch |err| {
                    std.debug.print("err: {}", .{err});
                    return .{ .literal = .{ .nil = true } };
                };
                return .{ .literal = .{ .number = number } };
            }
            return .{ .literal = .{ .nil = true } };
        } else if (self.match_1(tokens.TokenType.STRING)) {
            return .{ .literal = .{ .string = previous(self).literal } };
        }

        if (self.match_1(tokens.TokenType.LEFT_PAREN)) {
            const expr: Expr = expression(self);
            _ = consume(self, tokens.TokenType.RIGHT_PAREN, "Expect ')' after expression.");
            return .{ .grouping = .{ .expression = &expr } };
        }

        return .{ .literal = .{ .nil = false } };
    }

    pub fn parse(self: *Parser) Expr {
        return expression(self);
    }
};

// const Expr = union { binary: Binary, grouping: Grouping, literal: Literal, unary: Unary };
// const Expr = struct { Binary, Grouping, Literal, Unary };

const Expr = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    unary: Unary,

    const Binary = struct {
        left: *const Expr,
        operator: Token,
        right: *const Expr,
    };

    const Grouping = struct {
        expression: *const Expr,
    };

    const Literal = union(enum) {
        boolean: bool,
        number: f64,
        string: ?[]const u8,
        nil: ?bool,
    };

    const Unary = struct {
        operator: Token,
        right: *const Expr,
    };
};

pub fn astPrinter(allocator: Allocator, expr: Expr) std.fmt.AllocPrintError![]const u8 {
    std.debug.print("AST: {}\n", .{expr});

    return switch (expr) {
        .grouping => |e| {
            std.debug.print("Grouping: {}\n", .{e});
            _ = e.expression.*;
            const expression = e.expression.*;
            const nested = try astPrinter(allocator, expression);
            return std.fmt.allocPrint(allocator, "(group {s})", .{nested});
        },
        .binary => |e| {
            std.debug.print("Binary: {}\n", .{e});
            const left = try astPrinter(allocator, e.left.*);
            const right = try astPrinter(allocator, e.right.*);
            return std.fmt.allocPrint(allocator, "({s} {s} {s})", .{ e.operator.lexeme, left, right });
        },
        .unary => |e| {
            std.debug.print("Unary: {}\n", .{e});
            const expression = try astPrinter(allocator, e.right.*);
            return std.fmt.allocPrint(allocator, "({s} {s})", .{ e.operator.lexeme, expression });
        },
        .literal => |e| {
            std.debug.print("Literal: {}\n", .{e});
            switch (e) {
                .boolean => |v| {
                    if (v) {
                        return "true";
                    }
                    return "false";
                },
                .number => |v| {
                    return std.fmt.allocPrint(allocator, "{d}", .{v});
                },
                .string => |v| {
                    if (v) |v_not_null| {
                        return v_not_null;
                    }
                    return "ERROR, string null?";
                },
                .nil => |v| {
                    if (v != null) {
                        return "ERROR, nil not null?";
                    } else {
                        return "nil";
                    }
                },
            }
        },
    };
}
// fn parenthesize(allocator: Allocator, name: []const u8, left: *const Expr, right: *const Expr) !void {
//     std.debug.print("(", .{});
//     std.debug.print("{s}", .{name});
//     const l = left.*;
//     const rec_l = try astPrinter(allocator, l);
//     const r = right.*;
//     const rec_r = try astPrinter(allocator, r);
//     // const res = parenthesize(allocator, "test name", rec_l, rec_r);
//     std.debug.print("{s} {s}", .{ rec_l, rec_r });

//     std.debug.print(")", .{});
// }
