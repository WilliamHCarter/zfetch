const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const process = std.process;
const fetch = @import("../fetch.zig");

pub fn getLinuxPackages(allocator: Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    var has_previous = false;

    const apt_count = getAptPackages(allocator) catch 0;
    if (apt_count != 0) {
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (apt)", .{apt_count}));
        has_previous = true;
    }

    const dnf_count = getDnfPackages(allocator) catch 0;
    if (dnf_count != 0) {
        if (has_previous) try list.appendSlice(", ");
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (dnf)", .{dnf_count}));
        has_previous = true;
    }

    const pacman_count = getPacmanPackages(allocator) catch 0;
    if (pacman_count != 0) {
        if (has_previous) try list.appendSlice(", ");
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (pacman)", .{pacman_count}));
        has_previous = true;
    }

    const flatpak_count = getFlatpakPackages(allocator) catch 0;
    if (flatpak_count != 0) {
        if (has_previous) try list.appendSlice(", ");
        try list.appendSlice(try std.fmt.allocPrint(allocator, "{d} (flatpak)", .{flatpak_count}));
    }

    return list.toOwnedSlice();
}

fn getAptPackages(allocator: Allocator) !usize {
    const output = try fetch.execCommand(allocator, &[_][]const u8{ "dpkg-query", "-f", "${binary:Package}\n", "-W" }, "");
    defer allocator.free(output);

    var count: usize = 0;
    var iter = std.mem.split(u8, output, "\n");
    while (iter.next()) |_| {
        count += 1;
    }
    return count;
}

fn getDnfPackages(allocator: Allocator) !usize {
    const output = try fetch.execCommand(allocator, &[_][]const u8{ "rpm", "-qa" }, "");
    defer allocator.free(output);

    var count: usize = 0;
    var iter = std.mem.split(u8, output, "\n");
    while (iter.next()) |_| {
        count += 1;
    }
    return count;
}

fn getPacmanPackages(allocator: Allocator) !usize {
    const output = try fetch.execCommand(allocator, &[_][]const u8{ "pacman", "-Q" }, "");
    defer allocator.free(output);

    var count: usize = 0;
    var iter = std.mem.split(u8, output, "\n");
    while (iter.next()) |_| {
        count += 1;
    }
    return count;
}

fn getFlatpakPackages(allocator: Allocator) !usize {
    const output = try fetch.execCommand(allocator, &[_][]const u8{ "flatpak", "list", "--app" }, "");
    defer allocator.free(output);

    var count: usize = 0;
    var iter = std.mem.split(u8, output, "\n");
    while (iter.next()) |line| {
        if (line.len > 0) {
            count += 1;
        }
    }
    return count;
}
