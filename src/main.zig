const std = @import("std");
const commands = @import("commands.zig");
const fetch = @import("fetch.zig");

pub fn main(init: std.process.Init) !void {
    fetch.process_io = init.io;
    zfetch(init.minimal.args, init.gpa) catch |err| {
        switch (err) {
            error.InvalidCommand => std.debug.print("Invalid command. Use 'zfetch help' to see available commands.\n", .{}),
            error.MissingArgument => std.debug.print("Missing argument for the command. Use 'zfetch help' for usage information.\n", .{}),
            error.InvalidTheme => std.debug.print("The specified theme is invalid or not found. Use 'zfetch list-themes' to see available themes.\n", .{}),
            error.InvalidComponent => std.debug.print("The specified component is invalid or not found. Use 'zfetch list-components' to see available components.\n", .{}),
            error.FileNotFound => std.debug.print("A required file was not found. Please check your installation and theme files.\n", .{}),
            error.OutOfMemory => std.debug.print("Out of memory. Try closing other applications or increasing available memory.\n", .{}),
            error.AccessDenied => std.debug.print("Access denied. Try running the program with higher privileges.\n", .{}),
            error.InvalidArgument => std.debug.print("Invalid argument provided. Use 'zfetch help' for usage information.\n", .{}),
            else => std.debug.print("An unexpected error occurred. Please report this issue.\n", .{}),
        }
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}

fn zfetch(process_args: std.process.Args, allocator: std.mem.Allocator) !void {
    var arg_iter = try std.process.Args.Iterator.initAllocator(process_args, allocator);
    defer arg_iter.deinit();

    var args = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (args.items) |arg| allocator.free(arg);
        args.deinit();
    }

    while (arg_iter.next()) |arg| {
        try args.append(try allocator.dupe(u8, arg));
    }

    if (args.items.len < 2) return try commands.default(allocator);

    const cmd = try commands.parseCommand(args.items[1]);
    switch (cmd) {
        .Theme => try commands.loadGivenTheme(args.items[2..], allocator),
        .ListThemes => try commands.listThemes(),
        .Component => try commands.component(args.items[2..]),
        .ListComponents => try commands.listComponents(),
        .CustomLogo => try commands.customLogo(args.items[2..], allocator),
        .Help => try commands.help(),
    }
}
