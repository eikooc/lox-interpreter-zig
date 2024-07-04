const std = @import("std");
const lox = @import("./lox.zig");

pub fn main() !void {
    try lox.Lox.init();
}
