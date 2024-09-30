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

pub fn parseCommand(cmd: []const u8) !Command {
    const KV = struct { []const u8, Command };
    const map = try std.StaticStringMap(Command).init([_]KV{
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
    }, std.heap.page_allocator);

    return map.get(cmd) orelse CommandError.InvalidCommand;
}

pub fn default(allocator: std.mem.Allocator) !void {
    const theme = loadDefaultTheme() catch |err| {
        std.debug.print("Failed to load default theme: {any}\n", .{err});
        return;
    };
    try layout.render(theme, allocator);
}

pub fn loadDefaultTheme() !layout.Theme {
    const themes = try getAllThemes();
    for (themes.items) |theme| {
        if (std.mem.eql(u8, theme.name, "default")) {
            return layout.loadTheme(theme.content);
        }
    }
    return layout.loadTheme(themes.items[0].content);
}

pub fn loadGivenTheme(args: []const []const u8, allocator: std.mem.Allocator) !void {
    if (args.len == 0) return CommandError.MissingArgument;
    const themes = try getAllThemes();
    for (themes.items) |theme| {
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
    const themes = try getAllThemes();
    for (themes.items) |theme| {
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

pub fn getAllThemes() !std.ArrayList(Theme) {
    var themes = std.ArrayList(Theme).init(std.heap.page_allocator);

    inline for (theme_names) |name| {
        try themes.append(Theme{ .name = name, .content = @embedFile(name) });
    }
    return themes;
}
