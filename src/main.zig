const std = @import("std");
const info = @import("info.zig");
const layout = @import("layout.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const username = try info.getUsername();
    const os = try info.getOS();
    const cpu = try info.getCpu();
    const memory = try info.getMemory();
    const uptime = try info.getUptime();
    try layout.displayInfo(stdout, username, os, cpu, memory, uptime);
    // try stdout.print("Hello, {s}!\n", .{os});
}
