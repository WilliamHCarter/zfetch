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

pub fn parseCommand(cmd: []const u8) !Command {
    if (std.mem.eql(u8, cmd, "--theme")) return .Theme;
    if (std.mem.eql(u8, cmd, "-t")) return .Theme;
    if (std.mem.eql(u8, cmd, "--list-themes")) return .ListThemes;
    if (std.mem.eql(u8, cmd, "-l")) return .ListThemes;
    if (std.mem.eql(u8, cmd, "--set-theme")) return .SetTheme;
    if (std.mem.eql(u8, cmd, "--component")) return .Component;
    if (std.mem.eql(u8, cmd, "-c")) return .Component;
    if (std.mem.eql(u8, cmd, "--list-components")) return .ListComponents;
    if (std.mem.eql(u8, cmd, "--custom-logo")) return .CustomLogo;
    if (std.mem.eql(u8, cmd, "--help")) return .Help;
    if (std.mem.eql(u8, cmd, "-h")) return .Help;
    return CommandError.InvalidCommand;
}

pub fn default(allocator: std.mem.Allocator) !void {
    const theme_name = "default.txt";
    const theme = try layout.loadTheme("themes/" ++ theme_name);
    try layout.render(theme, allocator);
}

pub fn loadGivenTheme(args: []const []const u8, allocator: std.mem.Allocator) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    const themePath = try std.fmt.allocPrint(std.heap.page_allocator, "themes/{s}.txt", .{args[0]});
    const theme = layout.loadTheme(themePath) catch |err| {
        std.debug.print("Failed to load theme {s}: {any}\n", .{ args[0], err });
        return;
    };
    try layout.render(theme, allocator);
}

//TODO
pub fn listThemes() !void {
    std.debug.print("Listing themes...\n", .{});
}

//TODO
pub fn setTheme(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    std.debug.print("Setting theme to: {s}\n", .{args[0]});
}

pub fn component(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    std.debug.print("Displaying component: {s}\n", .{args[0]});
    var theme = layout.Theme.init("display_theme");

    const cmp = try layout.parseComponent(args[0]);
    try theme.components.append(cmp);
    try layout.render(theme, std.heap.page_allocator);
}

pub fn listComponents() !void {
    std.debug.print("Listing components:\n", .{});
    inline for (std.meta.fields(layout.ComponentKind)) |field| {
        std.debug.print("  {s}\n", .{field.name});
    }
}

//TODO
pub fn customLogo(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
}

pub fn help() !void {
    std.debug.print(
        \\Usage: zfetch [COMMAND] [ARGS]
        \\
        \\Commands:
        \\  -h,  --help                      Display this help information
        \\  -t,  --theme <theme_file>        Load a specific theme file
        \\  -l,  --list-themes               List available themes
        \\  -c,  --component <name>          Display a specific component
        \\       --list-components           List all available components
        \\       --set-theme <name>          Set the theme
        \\       --logo <file>               Use a custom ASCII art file as logo
        \\
    , .{});
}
