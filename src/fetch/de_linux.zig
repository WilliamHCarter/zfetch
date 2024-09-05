const std = @import("std");
const process = std.process;
const fs = std.fs;
const execCommand = @import("../fetch.zig").execCommand;

pub fn printDE(allocator: std.mem.Allocator, name: []const u8, version: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s} {s}\n", .{ name, version });
}

fn getLinuxDE(allocator: std.mem.Allocator) ![]const u8 {
    var name: []const u8 = undefined;
    var version: []const u8 = undefined;

    const xdg_current_desktop = try process.getEnvVarOwned(allocator, "XDG_CURRENT_DESKTOP");
    defer allocator.free(xdg_current_desktop);

    if (xdg_current_desktop.len > 0) {
        name = try allocator.dupe(u8, xdg_current_desktop);
        name = std.mem.trim(u8, name, ":");
        if (std.mem.eql(u8, name, "Budgie:GNOME")) {
            name = "Budgie";
        } else if (std.mem.eql(u8, name, "Unity7:ubuntu")) {
            name = "Unity";
        }
        version = try getDEVersion(allocator, name) orelse "";
        return printDE(allocator, name, version);
    }

    const desktop_session = try process.getEnvVarOwned(allocator, "DESKTOP_SESSION");
    defer allocator.free(desktop_session);

    if (desktop_session.len > 0) {
        name = try allocator.dupe(u8, fs.path.basename(desktop_session));
        return printDE(allocator, name, version);
    }

    if (process.getEnvVarOwned(allocator, "GNOME_DESKTOP_SESSION_ID")) |_| {
        name = "GNOME";
        version = try getDEVersion(allocator, name) orelse "";
        return printDE(allocator, name, version);
    } else |_| {}

    if (process.getEnvVarOwned(allocator, "MATE_DESKTOP_SESSION_ID")) |_| {
        name = "MATE";
        version = try getDEVersion(allocator, name) orelse "";
        return printDE(allocator, name, version);
    } else |_| {}

    if (process.getEnvVarOwned(allocator, "TDE_FULL_SESSION")) |_| {
        name = "Trinity";
        version = try getDEVersion(allocator, name) orelse "";
        return printDE(allocator, name, version);
    } else |_| {}

    if (try process.getEnvVarOwned(allocator, "DISPLAY")) |_| {
        const xprop_output = try execCommand(allocator, &[_][]const u8{ "xprop", "-root" });
        defer allocator.free(xprop_output);

        if (std.mem.indexOf(u8, xprop_output, "KDE_SESSION_VERSION")) |_| {
            name = "KDE";
        } else if (std.mem.indexOf(u8, xprop_output, "_MUFFIN")) |_| {
            name = "Cinnamon";
        } else if (std.mem.indexOf(u8, xprop_output, "xfce4")) |_| {
            name = "Xfce4";
        } else if (std.mem.indexOf(u8, xprop_output, "xfce5")) |_| {
            name = "Xfce5";
        }
    } else |_| {}

    version = try getDEVersion(allocator, name) orelse "";
    return printDE(allocator, name, version);
}

fn getDEVersion(allocator: std.mem.Allocator, de_name: []const u8) ![]const u8 {
    const commands = .{
        .{ "Plasma", &[_][]const u8{ "plasmashell", "--version" } },
        .{ "MATE", &[_][]const u8{ "mate-session", "--version" } },
        .{ "Xfce", &[_][]const u8{ "xfce4-session", "--version" } },
        .{ "GNOME", &[_][]const u8{ "gnome-shell", "--version" } },
        .{ "Cinnamon", &[_][]const u8{ "cinnamon", "--version" } },
        .{ "Budgie", &[_][]const u8{ "budgie-desktop", "--version" } },
        .{ "LXQt", &[_][]const u8{ "lxqt-session", "--version" } },
        .{ "Unity", &[_][]const u8{ "unity", "--version" } },
    };

    inline for (commands) |cmd| {
        if (std.mem.startsWith(u8, de_name, cmd[0])) {
            if (execCommand(allocator, cmd[1])) |output| {
                defer allocator.free(output);
                var iter = std.mem.split(u8, output, " ");
                _ = iter.next();
                if (iter.next()) |version| {
                    return allocator.dupe(u8, std.mem.trim(u8, version, &std.ascii.spaces));
                }
            } else |_| {}
            break;
        }
    }

    return "";
}
