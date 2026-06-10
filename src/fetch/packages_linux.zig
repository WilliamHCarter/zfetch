const std = @import("std");
const shared_io = @import("../utils/io.zig");
const Allocator = std.mem.Allocator;

pub fn getLinuxPackages(allocator: std.mem.Allocator) ![]const u8 {
    const io = shared_io.process;

    var apt = countFilesTask(io, "/var/lib/dpkg/info", ".list");
    var dnf = countFilesTask(io, "/var/lib/rpm", ".rpm");
    var pacman = countDirectoriesTask(io, "/var/lib/pacman/local", null);
    var flatpak = countDirectoriesTask(io, "/var/lib/flatpak/app", null);
    // /snap holds one directory per installed snap, plus the `bin` wrapper dir.
    var snap = countDirectoriesTask(io, "/snap", "bin");

    const package_managers = [_]struct { count: usize, name: []const u8 }{
        .{ .count = apt.await(io) catch 0, .name = "apt" },
        .{ .count = dnf.await(io) catch 0, .name = "dnf" },
        .{ .count = pacman.await(io) catch 0, .name = "pacman" },
        .{ .count = flatpak.await(io) catch 0, .name = "flatpak" },
        .{ .count = snap.await(io) catch 0, .name = "snap" },
    };

    var list = std.array_list.Managed(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;

    for (package_managers) |pm| {
        if (pm.count != 0) {
            if (has_previous) try list.appendSlice(", ");
            try list.print("{d} ({s})", .{ pm.count, pm.name });
            has_previous = true;
        }
    }

    return list.toOwnedSlice();
}

// Directory scans block on file IO, so `concurrent` to overlap them; the
// fallback covers single-threaded Io implementations, where they run serially.
fn countFilesTask(io: std.Io, dir_path: []const u8, extension: []const u8) std.Io.Future(anyerror!usize) {
    return io.concurrent(countFiles, .{ dir_path, extension }) catch
        io.async(countFiles, .{ dir_path, extension });
}

fn countDirectoriesTask(io: std.Io, dir_path: []const u8, exclude: ?[]const u8) std.Io.Future(anyerror!usize) {
    return io.concurrent(countDirectories, .{ dir_path, exclude }) catch
        io.async(countDirectories, .{ dir_path, exclude });
}

fn countFiles(dir_path: []const u8, extension: []const u8) anyerror!usize {
    const io = shared_io.process;
    var dir = std.Io.Dir.openDirAbsolute(io, dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close(io);

    var count: usize = 0;
    var iter = dir.iterate();

    while (try iter.next(io)) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, extension)) {
            count += 1;
        }
    }
    return count;
}

fn countDirectories(dir_path: []const u8, exclude: ?[]const u8) anyerror!usize {
    const io = shared_io.process;
    var dir = std.Io.Dir.openDirAbsolute(io, dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close(io);

    var count: usize = 0;
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
