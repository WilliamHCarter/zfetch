const std = @import("std");
const process = std.process;
const fs = std.fs;
const execCommand = @import("../fetch.zig").execCommand;

pub fn getLinuxDE(allocator: std.mem.Allocator) ![]const u8 {
    const xdg_current_desktop = try process.getEnvVarOwned(allocator, "XDG_CURRENT_DESKTOP");

    if (xdg_current_desktop.len > 0) {
        var desktops = std.mem.split(u8, xdg_current_desktop, ":");
        _ = desktops.next(); // Skip the first entry (distro)

        const name = try allocator.dupe(u8, desktops.next() orelse "");
        const version = try getDEVersion(allocator, name);

        return std.fmt.allocPrint(allocator, "{s} {s}", .{ name, version });
    }

    return detectDEFallback(allocator);
}

fn getDEVersion(allocator: std.mem.Allocator, de_name: []const u8) ![]const u8 {
    if (std.mem.eql(u8, de_name, "KDE")) {
        return getKDEVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "GNOME")) {
        return getGNOMEVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "Xfce")) {
        return getXfceVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "MATE")) {
        return getMATEVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "Cinnamon")) {
        return getCinnamonVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "Budgie")) {
        return getBudgieVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "LXQt")) {
        return getLXQtVersion(allocator);
    } else if (std.mem.eql(u8, de_name, "Unity")) {
        return getUnityVersion(allocator);
    }
    return allocator.dupe(u8, "");
}

fn getKDEVersion(allocator: std.mem.Allocator) ![]const u8 {
    if (try readVersionFromFile(allocator, "/usr/share/xsessions/plasma.desktop", "X-KDE-PluginInfo-Version=")) |version| {
        return version;
    }

    return execCommand(allocator, &[_][]const u8{ "plasmashell", "--version" }, "");
}

fn getGNOMEVersion(allocator: std.mem.Allocator) ![]const u8 {
    const quick_version = execCommand(allocator, &[_][]const u8{ "gsettings", "get", "org.gnome.shell", "welcome-dialog-last-shown-version" }, "") catch "";
    if (quick_version.len > 0) return std.mem.trim(u8, quick_version, "\'");

    const full_version = try execCommand(allocator, &[_][]const u8{ "gnome-shell", "--version" }, "");
    const version_start = std.mem.indexOf(u8, full_version, "GNOME Shell ") orelse 0;
    const trimmed_version = std.mem.trim(u8, full_version[version_start + 11 ..], &std.ascii.whitespace);

    return allocator.dupe(u8, trimmed_version);
}

fn getXfceVersion(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "xfce4-session", "--version" }, "");
}

fn getMATEVersion(allocator: std.mem.Allocator) ![]const u8 {
    if (try readVersionFromFile(allocator, "/usr/share/mate-about/mate-version.xml", "<platform>")) |version| {
        return version;
    }
    return execCommand(allocator, &[_][]const u8{ "mate-session", "--version" }, "");
}

fn getCinnamonVersion(allocator: std.mem.Allocator) ![]const u8 {
    if (process.getEnvVarOwned(allocator, "CINNAMON_VERSION")) |version| {
        return version;
    } else |_| {
        return execCommand(allocator, &[_][]const u8{ "cinnamon", "--version" }, "");
    }
}

fn getBudgieVersion(allocator: std.mem.Allocator) ![]const u8 {
    return try readVersionFromFile(allocator, "/usr/share/budgie/budgie-version.xml", "<str>") orelse
        allocator.dupe(u8, "");
}

fn getLXQtVersion(allocator: std.mem.Allocator) ![]const u8 {
    if (try readVersionFromFile(allocator, "/usr/share/cmake/lxqt/lxqt-config-version.cmake", "set ( PACKAGE_VERSION")) |version| {
        return version;
    }
    return execCommand(allocator, &[_][]const u8{ "lxqt-session", "-v" }, "");
}

fn getUnityVersion(allocator: std.mem.Allocator) ![]const u8 {
    return try readVersionFromFile(allocator, "/usr/bin/unity", "parser = OptionParser(version= \"%prog ") orelse
        allocator.dupe(u8, "");
}

fn readVersionFromFile(allocator: std.mem.Allocator, file_path: []const u8, search_string: []const u8) !?[]const u8 {
    const file = try std.fs.openFileAbsolute(file_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.indexOf(u8, line, search_string)) |index| {
            const version_start = index + search_string.len;
            const version = std.mem.trim(u8, line[version_start..], &std.ascii.whitespace);
            return try allocator.dupe(u8, version);
        }
    }

    return null;
}

fn detectDEFallback(allocator: std.mem.Allocator) ![]const u8 {
    const desktop_session = try process.getEnvVarOwned(allocator, "DESKTOP_SESSION");

    if (desktop_session.len > 0) {
        const name = try allocator.dupe(u8, fs.path.basename(desktop_session));
        const version = try getDEVersion(allocator, name);
        return std.fmt.allocPrint(allocator, "{s} {s}", .{ name, version });
    }
    return allocator.dupe(u8, "Unknown");
}
