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

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "card") and !std.mem.endsWith(u8, entry.name, "-")) {
            const path = try std.fs.path.join(allocator, &[_][]const u8{ "/sys/class/drm", entry.name, "device", "product_name" });
            const file = std.fs.openFileAbsolute(path, .{}) catch continue;
            defer file.close();

            const content = file.readToEndAlloc(allocator, 1024) catch continue;
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
    const result = try execCommand(allocator, &[_][]const u8{
        "lspci", "-mm",
    }, "");

    var gpu_list = std.ArrayList([]const u8).init(allocator);
    defer gpu_list.deinit();

    var lines = std.mem.split(u8, result, "\n");
    while (lines.next()) |line| {
        if (isGPULine(line)) {
            const gpu_info = try extractGPUInfo(allocator, line);
            try gpu_list.append(gpu_info);
        }
    }

    if (gpu_list.items.len >= 2) {
        if (std.mem.startsWith(u8, gpu_list.items[0], "Intel") and std.mem.startsWith(u8, gpu_list.items[1], "Intel")) {
            _ = gpu_list.orderedRemove(0);
        }
    }

    if (gpu_list.items.len > 0) {
        return try std.mem.join(allocator, " / ", gpu_list.items);
    }

    return "GPU Not Found";
}

fn isGPULine(line: []const u8) bool {
    return std.mem.indexOf(u8, line, "Display") != null or
        std.mem.indexOf(u8, line, "3D") != null or
        std.mem.indexOf(u8, line, "VGA") != null;
}

fn extractGPUInfo(allocator: std.mem.Allocator, line: []const u8) ![]const u8 {
    var fields = std.mem.split(u8, line, "\"");
    var field_index: usize = 0;
    var device_name: ?[]const u8 = null;
    var subsystem_name: ?[]const u8 = null;

    while (fields.next()) |field| {
        switch (field_index) {
            3 => device_name = field,
            5 => {
                if (field.len > 0 and !std.mem.startsWith(u8, field, "Device ")) {
                    subsystem_name = field;
                }
            },
            7 => {
                if (subsystem_name == null) {
                    subsystem_name = field;
                }
            },
            else => {},
        }
        field_index += 1;
    }

    if (device_name) |name| {
        if (subsystem_name) |subsys| {
            return try std.fmt.allocPrint(allocator, "{s} {s}", .{ name, subsys });
        } else {
            return try allocator.dupe(u8, name);
        }
    }

    return "Unknown GPU";
}
