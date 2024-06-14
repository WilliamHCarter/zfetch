const std = @import("std");

pub fn displayInfo(writer: anytype, username: []const u8, os: []const u8, cpu: []const u8, memory: []const u8, uptime: []const u8) !void {
    try writer.print("Username: {s}\n", .{username});
    try writer.print("OS: {s}\n", .{os});
    try writer.print("CPU: {s}\n", .{cpu});
    try writer.print("Memory: {s}\n", .{memory});
    try writer.print("Uptime: {s}\n", .{uptime});
}
