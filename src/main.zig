const std = @import("std");
const fetch = @import("fetch.zig");
const layout = @import("layout.zig");

pub fn main() !void {
    // const stdout = std.io.getStdOut().writer();
    // const username = try fetch.getUsername();
    // const os = try fetch.getOS();
    // const host = try fetch.getHostDevice();
    // const kernel = try fetch.getKernel();
    // const uptime = try fetch.getUptime();
    // const packages = try fetch.getPackages();
    // const shell = try fetch.getShell();
    // const resolution = try fetch.getResolution();
    // const de = try fetch.getDE();
    // const wm = try fetch.getWM();
    // const wmtheme = try fetch.getTheme();
    // const terminal = try fetch.getTerminal();
    // const cpu = try fetch.getCPU();
    // const gpu = try fetch.getGPU();
    // const memory = try fetch.getMemory();

    // // try layout.displayInfo(stdout, username, os, cpu, memory, uptime);
    // try stdout.print("User: {s}\n", .{username});
    // try stdout.print("OS: {s}\n", .{os});
    // try stdout.print("Host: {s}\n", .{host});
    // try stdout.print("Kernel: {s}\n", .{kernel});
    // try stdout.print("Uptime: {s}\n", .{uptime});
    // try stdout.print("Packages: {s}\n", .{packages});
    // try stdout.print("Shell: {s}\n", .{shell});
    // try stdout.print("Terminal: {s}\n", .{terminal});
    // try stdout.print("Resolution: {s}\n", .{resolution});
    // try stdout.print("DE: {s}\n", .{de});
    // try stdout.print("WM: {s}\n", .{wm});
    // try stdout.print("WM Theme: {s}\n", .{wmtheme});
    // try stdout.print("CPU: {s}\n", .{cpu});
    // try stdout.print("GPU: {s}\n", .{gpu});
    // try stdout.print("Memory: {s}\n", .{memory});
    const theme_name = "default"; // Or get from command line args
    const theme = try layout.loadTheme(theme_name);
    try layout.render(theme);
}
