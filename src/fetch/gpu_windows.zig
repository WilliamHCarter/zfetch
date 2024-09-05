const std = @import("std");
const windows = std.os.windows;
const fetch = @import("../fetch.zig");

pub fn getWindowsGPU(allocator: std.mem.Allocator) ![]const u8 {
    const result = try fetch.execCommand(allocator, &[_][]const u8{ "wmic", "path", "win32_VideoController", "get", "name" }, "Unknown");

    var lines = std.mem.split(u8, result, "\n");
    _ = lines.next();

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len > 0) {
            return allocator.dupe(u8, trimmed);
        }
    }

    return error.GpuNotFound;
}
