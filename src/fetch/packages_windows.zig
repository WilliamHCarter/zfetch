const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const env = @import("../utils/env.zig");
const fetch = @import("../fetch.zig");
const windows = @import("std.os.windows");

pub fn getWindowsPackages(allocator: Allocator) ![]const u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;
    const choco_count = getChocoPackages(allocator) catch 0;
    if (choco_count != 0) {
        if (has_previous) {
            try list.appendSlice(", ");
        }
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (choco)", .{choco_count}));
        has_previous = true;
    }
    const scoop_count = getScoopPackages(allocator) catch 0;
    if (scoop_count != 0) {
        if (has_previous) {
            try list.appendSlice(", ");
        }
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (scoop)", .{scoop_count}));
        has_previous = true;
    }

    return list.toOwnedSlice();
}

fn getChocoPackages(allocator: Allocator) !usize {
    const choco_env = env.getEnvVarOwned(allocator, "ChocolateyInstall") catch {
        return 0;
    };

    const choco_path = try fs.path.join(allocator, &[_][]const u8{ choco_env, "lib" });
    return countDirs(choco_path);
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

    const count: usize = try countDirs(scoop_path);
    return count - 1;
}

// This is slow, so we'll deal with it later maybe...
// fn getWingetPackages(allocator: allocator) !usize {
//     const winget_command = fetch.execCommand(allocator, &[_][]const u8{ "winget", "list", "--disable-interactivity" }, "") catch |err| {
//         std.debug.print("Error running winget: {}\n", .{err});
//         return 0;
//     };

//     //remove the header from the output
//     const header_start = std.mem.indexOf(u8, winget_command, "--\r\n");
//     if (header_start == null) return 0;

//     const trimmed_output = winget_command[header_start.? + 4 ..];

//     var count: usize = 0;
//     for (trimmed_output) |line| {
//         if (line == '\n') {
//             count += 1;
//         }
//     }
//     return count;
// }

fn countDirs(path: []const u8) !usize {
    var count: usize = 0;
    const io = std.Io.Threaded.global_single_threaded.io();
    var dir = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error opening directory: {}\n", .{err});
        return count;
    };

    defer dir.close(io);
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind == .directory) {
            count += 1;
        }
    }

    return count;
}
