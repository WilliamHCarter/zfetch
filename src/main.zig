const std = @import("std");
const fetch = @import("fetch.zig");
const layout = @import("layout.zig");
const commands = @import("commands.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("Memory leaks detected: {}\n", .{err});
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try commands.handleCommands(args, allocator);
}
