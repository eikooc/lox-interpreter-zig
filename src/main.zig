const std = @import("std");
const Lox = @import("./Lox.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    // Check for memory leaks in program during development
    defer {
        std.debug.print("leak? {}\n", .{gpa.deinit()});
    }

    const allocator = gpa.allocator();
    try Lox.init(allocator);
}
