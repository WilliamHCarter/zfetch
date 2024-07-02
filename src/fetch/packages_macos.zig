const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

pub fn getMacosPackages(allocator: mem.Allocator) ![]const u8 {
    const brew_count = try getBrewPackages(allocator);
    const macports_count = try getMacPortsPackages(allocator);

    var buffer: [20]u8 = undefined;
    const len = try std.fmt.bufPrint(&buffer, "{}", .{brew_count + macports_count});

    const formatted_str = try allocator.alloc(u8, len.len);
    @memcpy(formatted_str, buffer[0..len.len]);

    return formatted_str;
}

fn getBrewPackages(allocator: mem.Allocator) !usize {
    const homebrew_prefix = process.getEnvVarOwned(allocator, "HOMEBREW_PREFIX") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => "/opt/homebrew",
        else => return err,
    };
    defer allocator.free(homebrew_prefix);

    const cellar_path = try fs.path.join(allocator, &[_][]const u8{ homebrew_prefix, "Cellar" });
    defer allocator.free(cellar_path);

    return countDirs(cellar_path);
}

fn getMacPortsPackages(allocator: mem.Allocator) !usize {
    const macports_prefix = process.getEnvVarOwned(allocator, "MACPORTS_PREFIX") catch {
        return 0;
    };
    defer allocator.free(macports_prefix);

    const software_path = try fs.path.join(allocator, &[_][]const u8{ macports_prefix, "var", "macports", "software" });
    defer allocator.free(software_path);
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
