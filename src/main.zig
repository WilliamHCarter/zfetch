const std = @import("std");
const fetch = @import("fetch.zig");
const layout = @import("layout.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const username = try fetch.getUsername();
    const os = try fetch.getOS();
    const cpu = try fetch.getCPU();
    const memory = try fetch.getMemory();
    // const uptime = try fetch.getUptime();
    // try layout.displayInfo(stdout, username, os, cpu, memory, uptime);
    try stdout.print("User: {s}\n", .{username});
    try stdout.print("OS: {s}\n", .{os});
    try stdout.print("CPU: {s}\n", .{cpu});
    try stdout.print("Memory: {s}\n", .{memory});
}
