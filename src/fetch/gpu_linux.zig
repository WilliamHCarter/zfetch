const std = @import("std");

pub fn getLinuxGPU(allocator: std.mem.Allocator) ![]const u8 {
    const gpu_info = try getGPUInfoFromSys(allocator);
    if (gpu_info.len > 0) {
        return gpu_info;
    }

    return getGPUInfoFromLspci(allocator);
}

fn getGPUInfoFromSys(allocator: std.mem.Allocator) ![]const u8 {
    var dir = try std.fs.openIterableDirAbsolute("/sys/class/drm", .{});
    defer dir.close();

    var iter = dir.iterate();
    var gpu_list = std.ArrayList([]const u8).init(allocator);
    defer {
        for (gpu_list.items) |item| {
            allocator.free(item);
        }
        gpu_list.deinit();
    }

    while (try iter.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "card") and !std.mem.endsWith(u8, entry.name, "-")) {
            const path = try std.fs.path.join(allocator, &[_][]const u8{ "/sys/class/drm", entry.name, "device", "product_name" });
            defer allocator.free(path);

            if (std.fs.cwd().readFileAlloc(allocator, path, 1024)) |content| {
                const trimmed = std.mem.trim(u8, content, &std.ascii.spaces);
                try gpu_list.append(try allocator.dupe(u8, trimmed));
            } else |_| {}
        }
    }

    if (gpu_list.items.len > 0) {
        return try std.mem.join(allocator, " / ", gpu_list.items);
    }

    return "";
}

fn getGPUInfoFromLspci(allocator: std.mem.Allocator) ![]const u8 {
    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "lspci", "-mm", "-k", "-d", "::0300" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) {
        return error.LspciFailure;
    }

    var lines = std.mem.split(u8, result.stdout, "\n");
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
