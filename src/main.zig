const std = @import("std");
const lox = @import("./lox.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    // Check for memory leaks in program during development
    defer {
        std.debug.print("leak? {}\n", .{gpa.deinit()});
    }

    const allocator = gpa.allocator();
    try lox.Lox.init(allocator);
}
