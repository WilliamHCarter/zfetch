const std = @import("std");
const fetch = @import("fetch.zig");
const layout = @import("layout.zig");
const commands = @import("commands.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("Memory leaks detected: {}\n", .{err});
    }

    zfetch(allocator) catch |err| {
        const stderr = std.io.getStdErr().writer();
        switch (err) {
            error.InvalidCommand => stderr.print("Invalid command. Use 'zfetch help' to see available commands.\n", .{}) catch {},
            error.MissingArgument => stderr.print("Missing argument for the command. Use 'zfetch help' for usage information.\n", .{}) catch {},
            error.InvalidTheme => stderr.print("The specified theme is invalid or not found. Use 'zfetch list-themes' to see available themes.\n", .{}) catch {},
            error.InvalidComponent => stderr.print("The specified component is invalid or not found. Use 'zfetch list-components' to see available components.\n", .{}) catch {},
            error.FileNotFound => stderr.print("A required file was not found. Please check your installation and theme files.\n", .{}) catch {},
            error.OutOfMemory => stderr.print("Out of memory. Try closing other applications or increasing available memory.\n", .{}) catch {},
            error.AccessDenied => stderr.print("Access denied. Try running the program with higher privileges.\n", .{}) catch {},
            error.InvalidArgument => stderr.print("Invalid argument provided. Use 'zfetch help' for usage information.\n", .{}) catch {},
            else => stderr.print("An unexpected error occurred. Please report this issue.\n", .{}) catch {},
        }
        stderr.print("Error: {s}\n", .{@errorName(err)}) catch {};
        std.process.exit(1);
    };
}

fn zfetch(allocator: std.mem.Allocator) !void {
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
        .CustomLogo => try commands.customLogo(args[2..], allocator),
        .Help => try commands.help(),
    }
}
