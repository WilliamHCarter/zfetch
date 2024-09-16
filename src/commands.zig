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
    if (std.mem.eql(u8, cmd, "--logo")) return .CustomLogo;
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

pub fn listThemes() !void {
    var themesDir = try std.fs.cwd().openDir("themes", .{});
    defer themesDir.close();

    var iter = themesDir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        std.debug.print("  {s}\n", .{entry.name});
    }
}

pub fn setTheme(new_default: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const themes_dir = "themes/";
    var dir = try std.fs.openDirAbsolute(themes_dir, .{});
    defer dir.close();

    var itr = dir.iterate();
    while (try itr.next()) |entry| {
        if (entry.kind != .file) continue;

        const is_current_default = entry.name[0] == '*';
        const name_without_star = if (is_current_default) entry.name[1..] else entry.name;

        if (std.mem.eql(u8, name_without_star, new_default)) {
            if (!is_current_default) {
                const new_name = try std.fmt.allocPrint(allocator, "*{s}", .{entry.name});
                defer allocator.free(new_name);
                try dir.rename(entry.name, new_name);
            }
        } else if (is_current_default) {
            try dir.rename(
                entry.name,
                name_without_star,
            );
        }
    }
}

pub fn component(args: []const []const u8) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    std.debug.print("Displaying component: {s}\n", .{args[0]});
    var theme = layout.Theme.init("display_theme");

    const cmp = layout.parseComponent(args[0]) catch |err| {
        std.debug.print("Failed to load component {s}: {any}\n", .{ args[0], err });
        return;
    };
    try theme.components.append(cmp);
    layout.render(theme, std.heap.page_allocator) catch |err| {
        std.debug.print("Failed to render component {s}: {any}\n", .{ args[0], err });
    };
}

pub fn listComponents() !void {
    std.debug.print("Listing components:\n", .{});
    inline for (std.meta.fields(layout.ComponentKind)) |field| {
        std.debug.print("  {s}\n", .{field.name});
    }
}

pub fn customLogo(args: []const []const u8, allocator: std.mem.Allocator) !void {
    if (args.len == 0) return CommandError.MissingArgument;

    var theme = layout.Theme.init("custom_logo_theme");
    const comp_name = try std.fmt.allocPrint(allocator, "Logo image={s}", .{args[0]});
    defer allocator.free(comp_name);
    try theme.components.append(try layout.parseComponent(comp_name));

    try layout.render(theme, allocator);
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
