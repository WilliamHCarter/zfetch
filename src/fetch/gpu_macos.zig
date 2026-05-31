const std = @import("std");

fn execCommand(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    const io = std.Io.Threaded.global_single_threaded.io();
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(8192),
    });
    defer allocator.free(result.stderr);

    if (result.stderr.len > 0) {
        allocator.free(result.stdout);
        return error.CommandError;
    }

    return result.stdout;
}

pub fn getMacosGPU(allocator: std.mem.Allocator) ![]const u8 {
    const output = execCommand(allocator, &[_][]const u8{ "/usr/sbin/system_profiler", "SPDisplaysDataType" }) catch {
        return try allocator.dupe(u8, "GPU Not Found");
    };
    defer allocator.free(output);

    var gpus = std.array_list.Managed(u8).init(allocator);
    var lines = std.mem.splitSequence(u8, output, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (!std.mem.startsWith(u8, trimmed, "Chipset Model:")) continue;

        const name = std.mem.trim(u8, trimmed["Chipset Model:".len..], " \t");
        if (name.len == 0) continue;

        if (gpus.items.len != 0) try gpus.appendSlice(", ");
        try gpus.appendSlice(name);
    }

    if (gpus.items.len == 0) {
        gpus.deinit();
        return try allocator.dupe(u8, "GPU Not Found");
    }

    return gpus.toOwnedSlice();
}
