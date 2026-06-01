const std = @import("std");
const layout = @import("layout.zig");
const fetch = @import("fetch.zig");
const themes_list = @import("themes");

const Command = enum {
    Theme,
    ListThemes,
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

const command_map = std.StaticStringMap(Command).initComptime(.{
    .{ "--theme", .Theme },
    .{ "-t", .Theme },
    .{ "--list-themes", .ListThemes },
    .{ "-lt", .ListThemes },
    .{ "--component", .Component },
    .{ "-c", .Component },
    .{ "--list-components", .ListComponents },
    .{ "-lc", .ListComponents },
    .{ "--logo", .CustomLogo },
    .{ "-l", .CustomLogo },
    .{ "--help", .Help },
    .{ "-h", .Help },
});

pub fn parseCommand(cmd: []const u8) !Command {
    return command_map.get(cmd) orelse CommandError.InvalidCommand;
}

pub fn default(allocator: std.mem.Allocator) !void {
    const theme = loadDefaultTheme() catch |err| {
        std.debug.print("Failed to load default theme: {any}\n", .{err});
        return;
    };
    try layout.render(theme, allocator);
}

pub fn loadDefaultTheme() !layout.Theme {
    const themes = getAllThemes();
    for (themes) |theme| {
        if (std.mem.eql(u8, theme.name, "default")) {
            return layout.loadTheme(theme.content);
        }
    }
    return layout.loadTheme(themes[0].content);
}

pub fn loadGivenTheme(args: []const []const u8, allocator: std.mem.Allocator) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    const themes = getAllThemes();
    for (themes) |theme| {
        if (std.mem.eql(u8, theme.name, args[0])) {
            const given_theme = layout.loadTheme(theme.content) catch |err| {
                std.debug.print("Failed to load theme {s}: {any}\n", .{ args[0], err });
                return;
            };
            try layout.render(given_theme, allocator);
        }
    }
}

pub fn listThemes() !void {
    for (getAllThemes()) |theme| {
        std.debug.print("  {s}\n", .{theme.name});
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
        1 => try std.fmt.allocPrint(allocator, "Logo image={s} position=Left", .{args[0]}),
        2 => try std.fmt.allocPrint(allocator, "Logo image={s} {s}", .{ args[0], args[1] }),
        else => try std.fmt.allocPrint(allocator, "Logo image={s} {s}", .{ args[0], args[1] }),
    };
    defer allocator.free(comp_name);

    var theme = loadDefaultTheme() catch |err| {
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
        \\  -h,   --help                     Display this help information
        \\  -t,   --theme <theme_file>       Load a specific theme file
        \\  -l,   --logo <file>              Use a custom ASCII art file as logo
        \\  -c,   --component <name>         Display a specific component
        \\  -lt,  --list-themes              List available themes
        \\  -lc,  --list-components          List all available components
    , .{});
}

//=================== Theme Helpers ===================
pub const Theme = struct {
    name: []const u8,
    content: []const u8,
};

pub const theme_names = themes_list.names;

const all_themes = blk: {
    var themes: [theme_names.len]Theme = undefined;
    for (theme_names, 0..) |name, i| {
        themes[i] = .{ .name = name, .content = @embedFile(name) };
    }
    break :blk themes;
};

pub fn getAllThemes() []const Theme {
    return &all_themes;
}

//================================== Tests =====================================
test "parseCommand maps supported command aliases" {
    try std.testing.expectEqual(Command.Theme, try parseCommand("--theme"));
    try std.testing.expectEqual(Command.Theme, try parseCommand("-t"));
    try std.testing.expectEqual(Command.ListThemes, try parseCommand("--list-themes"));
    try std.testing.expectEqual(Command.ListThemes, try parseCommand("-lt"));
    try std.testing.expectEqual(Command.Component, try parseCommand("--component"));
    try std.testing.expectEqual(Command.Component, try parseCommand("-c"));
    try std.testing.expectEqual(Command.ListComponents, try parseCommand("--list-components"));
    try std.testing.expectEqual(Command.ListComponents, try parseCommand("-lc"));
    try std.testing.expectEqual(Command.CustomLogo, try parseCommand("--logo"));
    try std.testing.expectEqual(Command.CustomLogo, try parseCommand("-l"));
    try std.testing.expectEqual(Command.Help, try parseCommand("--help"));
    try std.testing.expectEqual(Command.Help, try parseCommand("-h"));
}

test "parseCommand rejects unknown commands" {
    try std.testing.expectError(CommandError.InvalidCommand, parseCommand("--not-a-command"));
}

test "embedded themes are available and parseable" {
    const themes = getAllThemes();
    try std.testing.expect(themes.len > 0);

    var saw_default = false;
    for (themes) |theme| {
        if (std.mem.eql(u8, theme.name, "default")) saw_default = true;
        const parsed = try layout.loadTheme(theme.content);
        try std.testing.expect(parsed.components.items.len > 0);
    }
    try std.testing.expect(saw_default);
}
