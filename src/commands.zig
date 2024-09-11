const std = @import("std");
const layout = @import("layout.zig");
const fetch = @import("fetch.zig");

const Command = enum {
    Theme,
    ListThemes,
    SetTheme,
    Component,
    ListComponents,
    CustomLogo,
    Help,
};

pub const CommandError = error{
    InvalidCommand,
    MissingArgument,
    InvalidTheme,
    InvalidComponent,
    FileNotFound,
};

pub fn handleCommands(args: []const []const u8, allocator: std.mem.Allocator) !void {
    if (args.len < 2) {
        try default(allocator);
        return;
    }

    const cmd = try parseCommand(args[1]);
    switch (cmd) {
        .Theme => try loadGivenTheme(args[2..], allocator),
        .ListThemes => try listThemes(),
        .SetTheme => try setTheme(args[2..]),
        .Component => try component(args[2..]),
        .ListComponents => try listComponents(),
        .CustomLogo => try customLogo(args[2..]),
        .Help => try help(),
    }
}

fn parseCommand(cmd: []const u8) !Command {
    if (std.mem.eql(u8, cmd, "--theme")) return .Theme;
    if (std.mem.eql(u8, cmd, "--list-themes")) return .ListThemes;
    if (std.mem.eql(u8, cmd, "--set-theme")) return .SetTheme;
    if (std.mem.eql(u8, cmd, "--component")) return .Component;
    if (std.mem.eql(u8, cmd, "--list-components")) return .ListComponents;
    if (std.mem.eql(u8, cmd, "--custom-logo")) return .CustomLogo;
    if (std.mem.eql(u8, cmd, "--help")) return .Help;
    return CommandError.InvalidCommand;
}

fn default(allocator: std.mem.Allocator) !void {
    const theme_name = "default.txt";
    const theme = try layout.loadTheme("themes/" ++ theme_name);
    try layout.render(theme, allocator);
}

fn loadGivenTheme(args: []const []const u8, allocator: std.mem.Allocator) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    const theme = try layout.loadTheme(args[0]);
    try layout.render(theme, allocator);
}

//TODO
fn listThemes() !void {
    std.debug.print("Listing themes...\n", .{});
}

//TODO
fn setTheme(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    std.debug.print("Setting theme to: {s}\n", .{args[0]});
}

//TODO
fn component(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    std.debug.print("Displaying component: {s}\n", .{args[0]});
}

//TODO
fn listComponents() !void {
    std.debug.print("Listing components...\n", .{});
}

//TODO
fn customLogo(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    std.debug.print("Setting custom logo: {s}\n", .{args[0]});
}

fn help() !void {
    std.debug.print(
        \\Usage: zfetch [COMMAND] [ARGS]
        \\
        \\Commands:
        \\  -h,  --help                      Display this help information
        \\  -c,  --component <name>          Display a specific component
        \\  -l,  --list-components           List all available components
        \\  -t,  --theme <theme_file>        Load a specific theme file
        \\       --list-themes               List available themes
        \\       --set-theme <name>          Set the theme
        \\       --logo <file>               Use a custom ASCII art file as logo
        \\
    , .{});
}
