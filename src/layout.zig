const std = @import("std");

pub fn displayInfo(writer: anytype, username: []const u8, os: []const u8, cpu: []const u8, memory: []const u8, uptime: []const u8) !void {
    try writer.print("Username: {s}\n", .{username});
    try writer.print("OS: {s}\n", .{os});
    try writer.print("CPU: {s}\n", .{cpu});
    try writer.print("Memory: {s}\n", .{memory});
    try writer.print("Uptime: {s}\n", .{uptime});
}

//TODO: Refactor unit display such that memory total and used each have their own units, based on what looks cleanest.
const MemoryUnit = enum {
    None,
    KB,
    MB,
    GB,
};

fn toFixedUnit(value: []const u8, unit: MemoryUnit, precision: u32) []const u8 {
    const divisor: f64 = switch (unit) {
        .None => 1,
        .KB => 1024,
        .MB => 1024 * 1024,
        .GB => 1024 * 1024 * 1024,
    };

    const floatValue: f64 = std.fmt.parseFloat(f64, std.mem.trim(u8, value, "\n")) catch -1.0;
    var buffer: [100]u8 = undefined;
    const formatted = std.fmt.formatFloat(buffer[0..], (floatValue / divisor), .{ .precision = precision, .mode = .decimal }) catch "-1.0";
    std.debug.print("formatted: {s}\n", .{formatted});
    return formatted;
}
