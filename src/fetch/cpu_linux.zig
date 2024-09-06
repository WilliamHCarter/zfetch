const std = @import("std");

fn getLinuxCPU(allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.openFileAbsolute("/proc/cpuinfo", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.split(u8, content, "\n");
    var model_name: ?[]const u8 = null;
    var cpu_cores: ?[]const u8 = null;

    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "model name")) |_| {
            const parts = std.mem.split(u8, line, ":");
            _ = parts.next();
            if (parts.next()) |value| {
                model_name = std.mem.trim(u8, value, " \t");
            }
        } else if (std.mem.indexOf(u8, line, "cpu cores")) |_| {
            const parts = std.mem.split(u8, line, ":");
            _ = parts.next();
            if (parts.next()) |value| {
                cpu_cores = std.mem.trim(u8, value, " \t");
            }
        }

        if (model_name != null and cpu_cores != null) {
            break;
        }
    }

    if (model_name) |name| {
        if (cpu_cores) |cores| {
            return try std.fmt.allocPrint(allocator, "{s} ({s} cores)", .{ name, cores });
        } else {
            return try allocator.dupe(u8, name);
        }
    }

    return "Unknown";
}
