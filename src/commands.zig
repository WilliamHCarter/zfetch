const std = @import("std");
const layout = @import("layout.zig");
const fetch = @import("fetch.zig");
const themes = @import("embed_themes");

const embedded_themes = std.StaticStringMap([]const u8).initComptime(.{
    .{ "default", themes.default_theme },
    .{ "minimal", themes.minimal_theme },
});

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
    const KV = struct { []const u8, Command };
    const map = try std.StaticStringMap(Command).initComptime([_]KV{
        .{ "--theme", .Theme },
        .{ "-t", .Theme },
        .{ "--list-themes", .ListThemes },
        .{ "-l", .ListThemes },
        .{ "--component", .Component },
        .{ "-c", .Component },
        .{ "--list-components", .ListComponents },
        .{ "--logo", .CustomLogo },
        .{ "--help", .Help },
        .{ "-h", .Help },
    });

    return map.get(cmd) orelse CommandError.InvalidCommand;
}

pub fn default(allocator: std.mem.Allocator) !void {
    const theme = loadDefaultTheme(allocator) catch |err| {
        std.debug.print("Failed to load default theme: {any}\n", .{err});
        return;
    };
    try layout.render(theme, allocator);
}

pub fn loadDefaultTheme(allocator: std.mem.Allocator) !layout.Theme {
    if (embedded_themes.get("default")) |theme_content| {
        return layout.parseTheme(theme_content);
    }

    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    const th_path = try std.fmt.allocPrint(allocator, "{s}/themes", .{cwd});
    defer allocator.free(th_path);

    var themes_dir = try std.fs.openDirAbsolute(th_path, .{});
    defer themes_dir.close();

    var iter = themes_dir.iterate();
    const theme_file = while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.eql(u8, entry.name, "default")) break entry.name;
        if (entry.name[0] != '.') break entry.name;
    } else return error.NoThemeFound;

    const theme_path = try std.fmt.allocPrint(allocator, "{s}/themes/{s}", .{ cwd, theme_file });
    defer allocator.free(theme_path);

    return layout.loadTheme(theme_path);
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
    var embedded_iter = embedded_themes.iterator();
    while (embedded_iter.next()) |entry| {
        std.debug.print("  {s}\n", .{entry.key});
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
    const comp_name = switch (args.len) {
        1 => try std.fmt.allocPrint(allocator, "Logo image={s}", .{args[0]}),
        2 => try std.fmt.allocPrint(allocator, "Logo image={s} {s}", .{ args[0], args[1] }),
        else => try std.fmt.allocPrint(allocator, "Logo image={s} {s}", .{ args[0], args[1] }),
    };
    defer allocator.free(comp_name);

    var theme = loadDefaultTheme(allocator) catch |err| {
        std.debug.print("Failed to load default theme: {any}\n", .{err});
        return;
    };

    var logo_index: ?usize = null;
    for (theme.components.items, 0..) |cmp, index| {
        if (cmp.kind == .Logo) {
            logo_index = index;
            break;
        }
    }

    if (logo_index) |index| {
        _ = theme.components.orderedRemove(index);
    }
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
