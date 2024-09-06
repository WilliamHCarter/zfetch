const std = @import("std");
const execCommand = @import("../fetch.zig").execCommand;

pub fn getLinuxGPU(allocator: std.mem.Allocator) ![]const u8 {
    const gpu_info = try getGPUInfoFromSys(allocator);
    if (gpu_info.len > 0) {
        return gpu_info;
    }

    return getGPUInfoFromLspci(allocator);
}

fn getGPUInfoFromSys(allocator: std.mem.Allocator) ![]const u8 {
    var dir = try std.fs.openDirAbsolute("/sys/class/drm", .{ .iterate = true });
    defer dir.close();

    var gpu_list = std.ArrayList([]const u8).init(allocator);
    defer {
        for (gpu_list.items) |item| {
            allocator.free(item);
        }
        gpu_list.deinit();
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "card") and !std.mem.endsWith(u8, entry.name, "-")) {
            const path = try std.fs.path.join(allocator, &[_][]const u8{ "/sys/class/drm", entry.name, "device", "product_name" });
            defer allocator.free(path);

            const file = std.fs.openFileAbsolute(path, .{}) catch continue;
            defer file.close();

            const content = file.readToEndAlloc(allocator, 1024) catch continue;
            defer allocator.free(content);

            const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
            try gpu_list.append(try allocator.dupe(u8, trimmed));
        }
    }

    if (gpu_list.items.len > 0) {
        return try std.mem.join(allocator, " / ", gpu_list.items);
    }

    return try allocator.dupe(u8, "");
}

fn getGPUInfoFromLspci(allocator: std.mem.Allocator) ![]const u8 {
    const result: []const u8 = try execCommand(allocator, &[_][]const u8{ "lspci", "-mm", "-k", "-d", "::0300" }, "");

    var lines = std.mem.split(u8, result, "\n");
    while (lines.next()) |line| {
        var fields = std.mem.split(u8, line, "\"");
        _ = fields.next();
        if (fields.next()) |vendor| {
            if (fields.next()) |_| {
                if (fields.next()) |device| {
                    return try std.fmt.allocPrint(allocator, "{s} {s}", .{ vendor, device });
                }
            }
        }
    }

    return "GPU Not Found";
}
