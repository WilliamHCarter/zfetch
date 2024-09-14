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

    if (args.len < 2) return try commands.default(allocator);

    const cmd = try commands.parseCommand(args[1]);
    switch (cmd) {
        .Theme => try commands.loadGivenTheme(args[2..], allocator),
        .ListThemes => try commands.listThemes(),
        .SetTheme => try commands.setTheme(args[2]),
        .Component => try commands.component(args[2..]),
        .ListComponents => try commands.listComponents(),
        .CustomLogo => try commands.customLogo(args[2..]),
        .Help => try commands.help(),
    }
}
