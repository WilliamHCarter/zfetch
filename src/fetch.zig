//==================================================================================================
// File:       fetch.zig
// Contents:   Functions used by zfetch to fetch system information based on the OS used.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");
const builtin = @import("builtin");
const info = @import("info.zig");

//================= Helper Functions =================
pub fn fetchEnvVar(key: []const u8) []const u8 {
    return std.process.getEnvVarOwned(std.heap.page_allocator, key) catch "Unknown";
}

pub fn toFixedFloat(value: []const u8, precision: u32) f64 {
    const floatValue = std.fmt.parseFloat(f64, std.mem.trim(u8, value, "\n")) catch {
        std.debug.print("Invalid float value: {s}\n", .{value});
        return 0.0;
    };
    const roundingFactor = std.math.pow(f64, 10, @floatFromInt(precision));
    const roundedValue = @round(floatValue * roundingFactor) / roundingFactor;

    return roundedValue;
}

pub fn execCommand(allocator: std.mem.Allocator, argv: []const []const u8, fallback: []const u8) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout orelse return fallback;
    const result = try stdout.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(result);

    const trimmed_result = std.mem.trim(u8, result, "\n");
    return allocator.dupe(u8, trimmed_result);
}

pub const KernelType = enum {
    Linux,
    Darwin,
    BSD,
    Windows,
    Unknown,
};

pub fn getKernelType() KernelType {
    return switch (builtin.os.tag) {
        .linux => .Linux,
        .macos => .Darwin,
        .freebsd, .openbsd, .netbsd, .dragonfly => .BSD,
        .windows => .Windows,
        else => .Unknown,
    };
}

//================= Fetch OS =================
pub fn getOS() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxOS(),
        .Darwin => darwinOS(),
        .BSD => bsdOS(),
        .Windows => windowsOS(),
        .Unknown => return error.UnknownOS,
    };
}

fn linuxOS() ![]const u8 {
    // const os_release = "/etc/os-release";
    // const file = std.fs.openFileAbsolute(os_release, .{}) catch return "Linux";
    // defer file.close();

    // var buf: [1024]u8 = undefined;
    // const contents = try file.readAll(&buf);

    // var iter = std.mem.split(contents, "\n");
    // while (iter.next()) |line| {
    //     if (std.mem.startsWith(u8, line, "PRETTY_NAME=")) {
    //         return std.mem.trim(u8, line[12..], "\"");
    //     }
    // }

    return "Linux";
}

fn darwinOS() ![]const u8 {
    const os_name = execCommand(std.heap.page_allocator, &[_][]const u8{ "sw_vers", "-productName" }, "macOS") catch |err| {
        std.debug.print("Error executing command: {}\n", .{err});
        return "Unknown macOS";
    };
    const os_version = execCommand(std.heap.page_allocator, &[_][]const u8{ "sw_vers", "-productVersion" }, "Unknown") catch |err| {
        std.debug.print("Error executing command: {}\n", .{err});
        return "Unknown version";
    };
    const os_version_name = info.darwinVersionName(os_version) catch |err| {
        std.debug.print("Error executing command: {}\n", .{err});
        return "";
    };
    return std.fmt.allocPrint(std.heap.page_allocator, "{s} {s} {s}", .{ os_name, os_version_name, os_version });
}

fn bsdOS() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn windowsOS() ![]const u8 {
    // const stdout = std.io.getStdOut().writer();
    // var info: std.os.windows.OSVERSIONINFOW = undefined;
    // info.dwOSVersionInfoSize = @sizeOf(std.os.windows.OSVERSIONINFOW);

    // if (std.os.windows.ntdll.RtlGetVersion(&info) != .SUCCESS) {
    //     try stdout.writeAll("Failed to retrieve Windows version information\n");
    //     return "Windows";
    // }

    // const os_string = try std.fmt.allocPrint(std.heap.page_allocator, "Windows {d}.{d}", .{
    //     info.dwMajorVersion,
    //     info.dwMinorVersion,
    // });
    // return os_string;
    return "Windows";
}

//================= Fetch CPU =================
pub fn getCPU() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxCPU(),
        .Darwin => darwinCPU(),
        .BSD => bsdCPU(),
        .Windows => windowsCPU(),
        .Unknown => return error.UnknownCPU,
    };
}

fn linuxCPU() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "lscpu", "-p=cpu" }, "Unknown");
}

fn darwinCPU() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "machdep.cpu.brand_string" }, "Unknown");
}

fn bsdCPU() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.model" }, "Unknown");
}

fn windowsCPU() ![]const u8 {
    // const stdout = std.io.getStdOut().writer();
    // var info: std.os.windows.SYSTEM_INFO = undefined;
    // std.os.windows.kernel32.GetSystemInfo(&info);

    // const cpu_string = try std.fmt.allocPrint(std.heap.page_allocator, "CPU: {d} cores", .{ info.dwNumberOfProcessors });
    // return cpu_string;
    return "Unknown";
}

//================= Fetch Memory =================
const MemoryUnit = enum {
    None,
    KB,
    MB,
    GB,
};

fn getDivisionFactor(unit: MemoryUnit) f64 {
    return switch (unit) {
        .None => 1,
        .KB => 1024,
        .MB => 1024 * 1024,
        .GB => 1024 * 1024 * 1024,
    };
}

pub fn getMemory() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxMemory(),
        .Darwin => darwinMemory(.GB),
        .BSD => bsdMemory(),
        .Windows => windowsMemory(),
        .Unknown => return error.UnknownMemory,
    };
}

fn linuxMemory() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "free", "-h" }, "Unknown");
}

fn darwinMemory(unit: MemoryUnit) ![]const u8 {
    const division_factor = getDivisionFactor(unit);
    const mem_size = try execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.memsize" }, "Unknown");
    const mem_size_in_unit: f64 = toFixedFloat(mem_size, 4);

    const mem_used = try execCommand(std.heap.page_allocator, &[_][]const u8{ "bash", "-c", "vm_stat | grep ' active\\|wired ' | sed 's/\\.//g' | awk '{s+=$NF} END {print s}'" }, "Unknown");
    const mem_used_in_unit: f64 = toFixedFloat(mem_used, 4);

    return std.fmt.allocPrint(std.heap.page_allocator, "{d} / {d}", .{ mem_used_in_unit / division_factor, mem_size_in_unit / division_factor });
}

fn bsdMemory() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.physmem" }, "Unknown");
}

fn windowsMemory() ![]const u8 {
    return "TODO";
}

//================= Fetch Functions =================

pub fn getUsername() ![]const u8 {
    return fetchEnvVar("USER");
}
