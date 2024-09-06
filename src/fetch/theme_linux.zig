const std = @import("std");
const getLinuxDE = @import("de_linux.zig").getLinuxDE;
const execCommand = @import("../fetch.zig").execCommand;

pub fn getLinuxTheme(allocator: std.mem.Allocator) ![]const u8 {
    const de_info = try getLinuxDE(allocator);
    defer allocator.free(de_info);

    var de_iter = std.mem.split(u8, de_info, " ");
    const de_name = de_iter.next() orelse return "Unknown";

    if (std.mem.eql(u8, de_name, "GNOME")) {
        return try getGnomeTheme(allocator);
    } else if (std.mem.eql(u8, de_name, "KDE")) {
        return try getKDETheme(allocator);
    } else if (std.mem.eql(u8, de_name, "Xfce")) {
        return try getXfceTheme(allocator);
    } else if (std.mem.eql(u8, de_name, "MATE")) {
        return try getMateTheme(allocator);
    } else if (std.mem.eql(u8, de_name, "Cinnamon")) {
        return try getCinnamonTheme(allocator);
    } else if (std.mem.eql(u8, de_name, "Budgie")) {
        return try getBudgieTheme(allocator);
    } else if (std.mem.eql(u8, de_name, "LXQt")) {
        return try getLXQtTheme(allocator);
    } else if (std.mem.eql(u8, de_name, "Unity")) {
        return try getUnityTheme(allocator);
    }

    return "Unknown";
}

fn getGnomeTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, "'\" \n"));
}

fn getKDETheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "kreadconfig5", "--group", "General", "--key", "Name", "--file", "kdeglobals",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, " \n"));
}

fn getXfceTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "xfconf-query", "-c", "xsettings", "-p", "/Net/ThemeName",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, " \n"));
}

fn getMateTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "gsettings", "get", "org.mate.interface", "gtk-theme",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, "'\" \n"));
}

fn getCinnamonTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "gsettings", "get", "org.cinnamon.desktop.interface", "gtk-theme",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, "'\" \n"));
}

fn getBudgieTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, "'\" \n"));
}

fn getLXQtTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "lxqt-config-appearance", "--get-gtk-theme",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, " \n"));
}

fn getUnityTheme(allocator: std.mem.Allocator) ![]const u8 {
    const result = try execCommand(allocator, &[_][]const u8{
        "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme",
    }, "");
    defer allocator.free(result);
    return allocator.dupe(u8, std.mem.trim(u8, result, "'\" \n"));
}
