const std = @import("std");
const execCommand = @import("../fetch.zig").execCommand;

pub fn getLinuxResolution(allocator: std.mem.Allocator) ![]const u8 {
    var resolution = std.ArrayList(u8).init(allocator);
    defer resolution.deinit();

    if (hasCommand(allocator, "xrandr")) {
        const result = try execCommand(allocator, &[_][]const u8{
            "xrandr", "--nograb", "--current",
        }, "");

        var lines = std.mem.split(u8, result, "\n");
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "current ")) |start_pos| {
                const end_pos = std.mem.indexOf(u8, line[start_pos..], ",") orelse line.len;
                return std.fmt.allocPrint(allocator, "{s}", .{line[start_pos + 8 .. start_pos + end_pos]});
            }
        }
    } else if (hasCommand(allocator, "xdpyinfo")) {
        const result = try execCommand(allocator, &[_][]const u8{ "sh", "-c", "xdpyinfo | grep dimensions: " }, "");

        var lines = std.mem.split(u8, result, "\n");
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "dimensions:")) |start_index| {
                const resolution_start = start_index + "dimensions:".len;
                const trimmed_resolution = std.mem.trim(u8, line[resolution_start..], " ");

                if (std.mem.indexOf(u8, trimmed_resolution, " pixels")) |end_index| {
                    return std.fmt.allocPrint(allocator, "{s}", .{trimmed_resolution[0..end_index]});
                }
            }
        }
    }
    return try allocator.dupe(u8, "Unknown");
}

fn hasCommand(allocator: std.mem.Allocator, command: []const u8) bool {
    const res = execCommand(allocator, &[_][]const u8{ "which", command }, "") catch return false;
    if (res.len == 0) return false;
    return true;
}
