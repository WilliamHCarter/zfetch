const std = @import("std");
const shared_io = @import("../utils/io.zig");
const fs = std.fs;
const mem = std.mem;
const env = @import("../utils/env.zig");

pub fn getMacosPackages(allocator: mem.Allocator) ![]const u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;

    const brew_count = getBrewPackages(allocator) catch 0;
    if (brew_count != 0) {
        try list.print("{d} (brew)", .{brew_count});
        has_previous = true;
    }

    const macports_count = getMacPortsPackages(allocator) catch 0;
    if (macports_count != 0) {
        if (has_previous) {
            try list.appendSlice(", ");
        }
        try list.print("{d} (macports)", .{macports_count});
    }

    return list.toOwnedSlice();
}

fn getBrewPackages(allocator: mem.Allocator) !usize {
    const homebrew_prefix = env.getEnvVarOwned(allocator, "HOMEBREW_PREFIX") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => "/opt/homebrew",
        else => return err,
    };

    const cellar_path = try fs.path.join(allocator, &[_][]const u8{ homebrew_prefix, "Cellar" });
    return countDirs(cellar_path);
}

fn getMacPortsPackages(allocator: mem.Allocator) !usize {
    const macports_prefix = env.getEnvVarOwned(allocator, "MACPORTS_PREFIX") catch {
        return 0;
    };
    const software_path = try fs.path.join(allocator, &[_][]const u8{ macports_prefix, "var", "macports", "software" });
    return countDirs(software_path);
}

fn countDirs(path: []const u8) !usize {
    var count: usize = 0;
    const io = shared_io.process;
    var dir = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch return count;

    defer dir.close(io);
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind == .directory) {
            count += 1;
        }
    }

    return count;
}
