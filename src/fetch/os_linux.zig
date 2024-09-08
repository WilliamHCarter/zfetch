const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;

pub fn getLinuxOS(allocator: mem.Allocator) ![]const u8 {
    var uname: os.linux.utsname = undefined;
    const result = os.linux.uname(&uname);
    if (result != 0) {
        return "Unknown Linux";
    }

    if (try readFile(allocator, "/etc/os-release")) |content| {
        if (getValueFromOSRelease(content, "PRETTY_NAME")) |prettyName| {
            return try std.fmt.allocPrint(allocator, "{s} {s}", .{ prettyName, uname.machine });
        }
    }

    if (try readFile(allocator, "/etc/lsb-release")) |content| {
        if (getValueFromLsbRelease(content, "DISTRIB_DESCRIPTION")) |description| {
            return try std.fmt.allocPrint(allocator, "{s} {s}", .{ description, uname.machine });
        }
    }

    return try std.fmt.allocPrint(allocator, "{s} {s}", .{ uname.sysname, uname.release });
}

fn readFile(allocator: mem.Allocator, path: []const u8) !?[]u8 {
    const file = fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn getValueFromOSRelease(content: []const u8, key: []const u8) ?[]const u8 {
    var lines = mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, key)) {
            var parts = mem.split(u8, line, "=");
            _ = parts.next();
            if (parts.next()) |value| {
                const trimmed = mem.trim(u8, value, "\"");
                return mem.trim(u8, trimmed, &std.ascii.whitespace);
            }
        }
    }
    return null;
}

fn getValueFromLsbRelease(content: []const u8, key: []const u8) ?[]const u8 {
    var lines = mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, key)) {
            var parts = mem.split(u8, line, "=");
            _ = parts.next();
            if (parts.next()) |value| {
                return mem.trim(u8, value, "\"");
            }
        }
    }
    return null;
}
