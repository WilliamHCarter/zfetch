const std = @import("std");
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

pub fn getDistroID(allocator: mem.Allocator) !?[]const u8 {
    const content = (try readFile(allocator, "/etc/os-release")) orelse return null;

    var lines = mem.splitSequence(u8, content, "\n");
    while (lines.next()) |line| {
        var parts = mem.splitSequence(u8, line, "=");
        const key = parts.next() orelse continue;
        if (!mem.eql(u8, key, "ID")) continue;
        const value = parts.next() orelse continue;
        return mem.trim(u8, mem.trim(u8, value, "\""), &std.ascii.whitespace);
    }
    return null;
}

fn readFile(allocator: mem.Allocator, path: []const u8) !?[]u8 {
    const io = std.Io.Threaded.global_single_threaded.io();
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited) catch return null;
}

fn getValueFromOSRelease(content: []const u8, key: []const u8) ?[]const u8 {
    var lines = mem.splitSequence(u8, content, "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, key)) {
            var parts = mem.splitSequence(u8, line, "=");
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
    var lines = mem.splitSequence(u8, content, "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, key)) {
            var parts = mem.splitSequence(u8, line, "=");
            _ = parts.next();
            if (parts.next()) |value| {
                return mem.trim(u8, value, "\"");
            }
        }
    }
    return null;
}
