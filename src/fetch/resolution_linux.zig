const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;

pub fn getLinuxResolution(allocator: mem.Allocator) ![]const u8 {
    var dir = try fs.openDirAbsolute("/sys/class/drm", .{ .iterate = true });
    defer dir.close();

    var resolutions = std.ArrayList([]const u8).init(allocator);
    defer {
        for (resolutions.items) |res| {
            allocator.free(res);
        }
        resolutions.deinit();
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .directory or !std.mem.startsWith(u8, entry.name, "card")) {
            continue;
        }

        const modes_path = try fmt.allocPrint(allocator, "/sys/class/drm/{s}/modes", .{entry.name});
        defer allocator.free(modes_path);

        const modes = fs.openFileAbsolute(modes_path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer modes.close();

        const content = try modes.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        var lines = mem.split(u8, content, "\n");
        if (lines.next()) |first_mode| {
            const resolution = try allocator.dupe(u8, first_mode);
            try resolutions.append(resolution);
        }
    }

    if (resolutions.items.len == 0) {
        return error.NoResolutionsFound;
    }

    if (resolutions.items.len == 1) {
        return try fmt.allocPrint(allocator, "{s}", .{resolutions.items[0]});
    }

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    for (resolutions.items, 0..) |res, i| {
        if (i > 0) {
            try result.appendSlice(", ");
        }
        try result.appendSlice(res);
    }

    return result.toOwnedSlice();
}
