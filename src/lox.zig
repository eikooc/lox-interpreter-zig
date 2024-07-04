const std = @import("std");
const Tokens = @import("./token-type.zig");
const Scanner = @import("./scanner.zig");
const Allocator = std.mem.Allocator;

pub const Lox = struct {
    hadError: bool = false,

    pub fn init() !void {
        const args = try std.process.argsAlloc(std.heap.page_allocator);
        defer std.process.argsFree(std.heap.page_allocator, args);

        if (args.len > 2) {
            std.log.err("Usage: lox [script]", .{});
            std.os.linux.exit(64);
        } else if (args.len == 2) {
            try runFile(args[1]);
        } else {
            try runPrompt();
        }
    }
};

fn readSourceFile(allocator: Allocator, path: []const u8) ![]const u8 {
    const file_content = try std.fs.cwd().readFileAlloc(allocator, path, 512);

    return file_content;
}

fn runFile(path: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const file_content = try readSourceFile(allocator, path);
    defer allocator.free(file_content);

    try run(file_content);
}

fn run(source: []const u8) !void {
    const allocator = std.heap.page_allocator;

    var scanner = Scanner.Scanner{
        .source = source,
        .allocator = allocator,
        .token_list = std.ArrayList(Tokens.Token).init(allocator),
    };

    const tokens = try scanner.scanTokens();

    // For now we just print out the tokens to see things are working
    // We should do something more interestin with them,
    // when we have a parser.
    for (tokens.items) |token| {
        std.debug.print("Token: {s}\n", .{try token.toString(allocator)});
    }
}

fn runPrompt() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buf: [100]u8 = undefined;

    while (true) {
        try stdout.print("> ", .{});

        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            try stdout.print("{s}\n", .{user_input});
            try run(user_input);
        } else {
            try stdout.print("Unexpected input\n", .{});
        }
    }
}

const assert = std.debug.assert;
