const std = @import("std");
const shared_io = @import("../utils/io.zig");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const env = @import("../utils/env.zig");

pub fn getWindowsPackages(allocator: Allocator) ![]const u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;
    const choco_count = getChocoPackages(allocator) catch 0;
    if (choco_count != 0) {
        if (has_previous) {
            try list.appendSlice(", ");
        }
        try list.print("{d} (choco)", .{choco_count});
        has_previous = true;
    }
    const scoop_count = getScoopPackages(allocator) catch 0;
    if (scoop_count != 0) {
        if (has_previous) {
            try list.appendSlice(", ");
        }
        try list.print("{d} (scoop)", .{scoop_count});
        has_previous = true;
    }

    return list.toOwnedSlice();
}

fn getChocoPackages(allocator: Allocator) !usize {
    const choco_env = env.getEnvVarOwned(allocator, "ChocolateyInstall") catch {
        return 0;
    };

    const choco_path = try fs.path.join(allocator, &[_][]const u8{ choco_env, "lib" });
    return countDirs(choco_path, null);
}

fn getScoopPackages(allocator: Allocator) !usize {
    var scoop_path: []const u8 = undefined;
    const scoop_env: []u8 = env.getEnvVarOwned(allocator, "SCOOP") catch &[_]u8{};

    if (scoop_env.len != 0) {
        scoop_path = try fs.path.join(allocator, &[_][]const u8{ scoop_env, "apps" });
    } else {
        const home_dir = try env.getEnvVarOwned(allocator, "USERPROFILE");
        scoop_path = try fs.path.join(allocator, &[_][]const u8{ home_dir, "scoop", "apps" });
    }

    // `apps` holds one directory per installed app, plus scoop's own install dir.
    return countDirs(scoop_path, "scoop");
}

fn countDirs(path: []const u8, exclude: ?[]const u8) !usize {
    var count: usize = 0;
    const io = shared_io.process;
    var dir = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch return count;

    defer dir.close(io);
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        if (exclude) |name| {
            if (std.mem.eql(u8, entry.name, name)) continue;
        }
        count += 1;
    }

    return count;
}
