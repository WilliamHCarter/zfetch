const std = @import("std");
const getLinuxDE = @import("de_linux.zig").getLinuxDE;
const execCommand = @import("../fetch.zig").execCommand;

const DEThemeCommand = struct {
    name: []const u8,
    command: []const []const u8,
};

const de_theme_commands = [_]DEThemeCommand{
    .{ .name = "GNOME", .command = &[_][]const u8{ "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme" } },
    .{ .name = "KDE", .command = &[_][]const u8{ "kreadconfig5", "--group", "General", "--key", "Name", "--file", "kdeglobals" } },
    .{ .name = "Xfce", .command = &[_][]const u8{ "xfconf-query", "-c", "xsettings", "-p", "/Net/ThemeName" } },
    .{ .name = "MATE", .command = &[_][]const u8{ "gsettings", "get", "org.mate.interface", "gtk-theme" } },
    .{ .name = "Cinnamon", .command = &[_][]const u8{ "gsettings", "get", "org.cinnamon.desktop.interface", "gtk-theme" } },
    .{ .name = "Budgie", .command = &[_][]const u8{ "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme" } },
    .{ .name = "LXQt", .command = &[_][]const u8{ "lxqt-config-appearance", "--get-gtk-theme" } },
    .{ .name = "Unity", .command = &[_][]const u8{ "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme" } },
};

fn getThemeFromCommand(allocator: std.mem.Allocator, command: []const []const u8) ![]const u8 {
    const result = try execCommand(allocator, command, "");
    return allocator.dupe(u8, std.mem.trim(u8, result, "'\" \n"));
}

pub fn getLinuxTheme(allocator: std.mem.Allocator) ![]const u8 {
    const de_info = try getLinuxDE(allocator);
    var de_iter = std.mem.split(u8, de_info, " ");
    const de_name = de_iter.next() orelse return "Unknown";

    for (de_theme_commands) |de_command| {
        if (std.mem.eql(u8, de_name, de_command.name)) {
            return try getThemeFromCommand(allocator, de_command.command);
        }
    }

    return "Unknown";
}
