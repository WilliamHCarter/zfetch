const std = @import("std");
const builtin = @import("builtin");

//================= Helpers =================
pub fn fetchEnvVar(key: []const u8) []const u8 {
    return std.process.getEnvVarOwned(std.heap.page_allocator, key) catch "Unknown";
}

fn execCommand(allocator: std.mem.Allocator, argv: []const []const u8, fallback: []const u8) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);

    const result = try child.stdout.?.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(result);

    const wait_result = try child.wait();
    if (wait_result != .Exited or wait_result.Exited != 0) {
        return fallback;
    }

    return std.mem.trim(u8, result, "\n");
}

const KernelType = enum {
    Linux,
    Darwin,
    BSD,
    Windows,
    Unknown,
};

fn getKernelType() KernelType {
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
    const os_release = "/etc/os-release";
    const file = std.fs.openFileAbsolute(os_release, .{}) catch return "Linux";
    defer file.close();

    var buf: [1024]u8 = undefined;
    const contents = try file.readAll(&buf);

    var iter = std.mem.split(contents, "\n");
    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "PRETTY_NAME=")) {
            return std.mem.trim(u8, line[12..], "\"");
        }
    }

    return "Linux";
}

fn darwinOS() ![]const u8 {
    const os_name = try execCommand(std.heap.page_allocator, &[_][]const u8{ "sw_vers", "-productName" }, "macOS");
    const os_version = try darwinOSVersion();

    return try std.fmt.allocPrint(std.heap.page_allocator, "{s} {s}", .{ os_name, os_version });
}

fn darwinOSVersion() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "sw_vers", "-productVersion" }, "Unknown");
}

fn bsdOS() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn windowsOS() ![]const u8 {
    const stdout = std.io.getStdOut().writer();
    var info: std.os.windows.OSVERSIONINFOW = undefined;
    info.dwOSVersionInfoSize = @sizeOf(std.os.windows.OSVERSIONINFOW);

    if (std.os.windows.ntdll.RtlGetVersion(&info) != .SUCCESS) {
        try stdout.writeAll("Failed to retrieve Windows version information\n");
        return "Windows";
    }

    const os_string = try std.fmt.allocPrint(std.heap.page_allocator, "Windows {d}.{d}", .{
        info.dwMajorVersion,
        info.dwMinorVersion,
    });
    return os_string;
}

//================= Fetch Functions =================

pub fn getUsername() ![]const u8 {
    return fetchEnvVar("USER");
}
