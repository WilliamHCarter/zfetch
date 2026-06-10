const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;

pub const PackageCounts = struct {
    apt: usize = 0,
    dnf: usize = 0,
    pacman: usize = 0,
    flatpak: usize = 0,
    snap: usize = 0,
};

pub fn getLinuxPackages(allocator: std.mem.Allocator) ![]const u8 {
    var counts = PackageCounts{};

    const threads = [_]Thread{
        try Thread.spawn(.{}, getAptPackages, .{&counts}),
        try Thread.spawn(.{}, getDnfPackages, .{&counts}),
        try Thread.spawn(.{}, getPacmanPackages, .{&counts}),
        try Thread.spawn(.{}, getFlatpakPackages, .{&counts}),
        try Thread.spawn(.{}, getSnapPackages, .{&counts}),
    };

    for (threads) |thread| {
        thread.join();
    }

    var list = std.array_list.Managed(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;

    const package_managers = [_]struct { count: usize, name: []const u8 }{
        .{ .count = counts.apt, .name = "apt" },
        .{ .count = counts.dnf, .name = "dnf" },
        .{ .count = counts.pacman, .name = "pacman" },
        .{ .count = counts.flatpak, .name = "flatpak" },
        .{ .count = counts.snap, .name = "snap" },
    };

    for (package_managers) |pm| {
        if (pm.count != 0) {
            if (has_previous) try list.appendSlice(", ");
            try list.print("{d} ({s})", .{ pm.count, pm.name });
            has_previous = true;
        }
    }

    return list.toOwnedSlice();
}

fn getAptPackages(counts: *PackageCounts) !void {
    counts.apt = try countFiles("/var/lib/dpkg/info", ".list");
}

fn getDnfPackages(counts: *PackageCounts) !void {
    counts.dnf = try countFiles("/var/lib/rpm", ".rpm");
}

fn getPacmanPackages(counts: *PackageCounts) !void {
    counts.pacman = try countDirectories("/var/lib/pacman/local", null);
}

fn getFlatpakPackages(counts: *PackageCounts) !void {
    counts.flatpak = try countDirectories("/var/lib/flatpak/app", null);
}

fn getSnapPackages(counts: *PackageCounts) !void {
    // /snap holds one directory per installed snap, plus the `bin` wrapper dir.
    counts.snap = try countDirectories("/snap", "bin");
}

fn countFiles(dir_path: []const u8, extension: []const u8) !usize {
    const io = std.Io.Threaded.global_single_threaded.io();
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

fn countDirectories(dir_path: []const u8, exclude: ?[]const u8) !usize {
    const io = std.Io.Threaded.global_single_threaded.io();
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
