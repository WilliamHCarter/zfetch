const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

pub fn getMacosPackages(allocator: mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;

    const brew_count = getBrewPackages(allocator) catch 0;
    if (brew_count != 0) {
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (brew)", .{brew_count}));
        has_previous = true;
    }

    const macports_count = getMacPortsPackages(allocator) catch 0;
    if (macports_count != 0) {
        if (has_previous) {
            try list.appendSlice(", ");
        }
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (macports)", .{macports_count}));
    }

    return list.toOwnedSlice();
}

fn getBrewPackages(allocator: mem.Allocator) !usize {
    const homebrew_prefix = process.getEnvVarOwned(allocator, "HOMEBREW_PREFIX") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => "/opt/homebrew",
        else => return err,
    };

    const cellar_path = try fs.path.join(allocator, &[_][]const u8{ homebrew_prefix, "Cellar" });
    return countDirs(cellar_path);
}

fn getMacPortsPackages(allocator: mem.Allocator) !usize {
    const macports_prefix = process.getEnvVarOwned(allocator, "MACPORTS_PREFIX") catch {
        return 0;
    };
    const software_path = try fs.path.join(allocator, &[_][]const u8{ macports_prefix, "var", "macports", "software" });
    return countDirs(software_path);
}

fn countDirs(path: []const u8) !usize {
    var count: usize = 0;
    var dir = fs.openDirAbsolute(path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error opening directory: {}\n", .{err});
        return count;
    };

    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .directory) {
            count += 1;
        }
    }

    return count;
}
