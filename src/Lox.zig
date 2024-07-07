const std = @import("std");
const Tokens = @import("./token-type.zig");
const Scanner = @import("./scanner.zig");
const Allocator = std.mem.Allocator;
const lox_parser = @import("./parser.zig");

hadError: bool = false,

pub fn init(allocator: Allocator) !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        std.log.err("Usage: lox [script]", .{});
        std.os.linux.exit(64);
    } else if (args.len == 2) {
        try runFile(allocator, args[1]);
    } else {
        try runPrompt(allocator);
    }
}

fn readSourceFile(allocator: Allocator, path: []const u8) ![]const u8 {
    const file_content = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));

    return file_content;
}

fn runFile(allocator: Allocator, path: []const u8) !void {
    const file_content = try readSourceFile(allocator, path);
    defer allocator.free(file_content);

    try run(allocator, file_content);
}

fn run(allocator: Allocator, source: []const u8) !void {
    var scanner = Scanner.Scanner{
        .source = source,
        .allocator = allocator,
        .token_list = std.ArrayList(Tokens.Token).init(allocator),
    };
    defer scanner.token_list.deinit();

    const tokens = try scanner.scanTokens();

    // For now we just print out the tokens to see things are working
    // We should do something more interestin with them,
    // when we have a parser.
    for (tokens.items) |token| {
        const token_as_string = try token.toString(allocator);
        defer allocator.free(token_as_string);

        std.debug.print("Token: {s}\n", .{token_as_string});
    }

    std.debug.print("About to parser init\n", .{});

    var parser = lox_parser.Parser.init(tokens);
    std.debug.print("About to parse\n", .{});
    // _ = parser.parse();
    const expression = parser.parse();
    const ast = try lox_parser.astPrinter(allocator, expression);
    defer allocator.free(ast);
    std.debug.print("Token: {s}\n", .{ast});
}

fn runPrompt(allocator: Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buf: [100]u8 = undefined;

    while (true) {
        try stdout.print("> ", .{});

        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            try stdout.print("{s}\n", .{user_input});
            try run(allocator, user_input);
        } else {
            try stdout.print("Unexpected input\n", .{});
        }
    }
}

const assert = std.debug.assert;
