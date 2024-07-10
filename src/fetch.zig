//==================================================================================================
// File:       fetch.zig
// Contents:   Functions used by zfetch to fetch system information based on the OS used.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");
const builtin = @import("builtin");
const info = @import("info.zig");
const packages = @import("fetch/packages_macos.zig");
const host = @import("fetch/host_macos.zig");
const resolution = @import("fetch/resolution_macos.zig");
const gpu = @import("fetch/gpu_macos.zig");
const wm = @import("fetch/wm_macos.zig");
const os = @import("fetch/os_macos.zig");
//================= Helper Functions =================
pub fn fetchEnvVar(allocator: std.mem.Allocator, key: []const u8) []const u8 {
    return std.process.getEnvVarOwned(allocator, key) catch "Unknown";
}

pub fn toFixedFloat(value: []const u8, precision: u32) []const u8 {
    const floatValue = std.fmt.parseFloat(f64, std.mem.trim(u8, value, "\n")) catch {
        std.debug.print("Invalid float value: {s}\n", .{value});
        return "0.0";
    };

    var buf: [64]u8 = undefined;
    const options = std.fmt.FormatOptions{
        .precision = precision,
    };

    const result = std.fmt.formatFloat(buf[0..], floatValue, options) catch {
        std.debug.print("Failed to format float value: {d}\n", .{floatValue});
        return "0.0";
    };

    return result;
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
pub fn getOS(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxOS(),
        .Darwin => darwinOS(arena_allocator),
        .BSD => bsdOS(arena_allocator),
        .Windows => windowsOS(),
        .Unknown => return error.UnknownOS,
    };

    return allocator.dupe(u8, result);
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

fn darwinOS(allocator: std.mem.Allocator) ![]const u8 {
    const os_struct = try os.parseOS(allocator);
    const os_name = os_struct.name;
    const os_version_name = os_struct.version;
    const os_version = os_struct.buildVersion;
    return try std.fmt.allocPrint(allocator, "{s} {s} {s}", .{ os_name, os_version_name, os_version });
}

fn bsdOS(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn windowsOS() ![]const u8 {
    // const stdout = std.io.getStdOut().writer();
    // var info: std.os.windows.OSVERSIONINFOW = undefined;
    // info.dwOSVersionInfoSize = @sizeOf(std.os.windows.OSVERSIONINFOW);

    // if (std.os.windows.ntdll.RtlGetVersion(&info) != .SUCCESS) {
    //     try stdout.writeAll("Failed to retrieve Windows version information\n");
    //     return "Windows";
    // }

    // const os_string = try std.fmt.allocPrint(allocator, "Windows {d}.{d}", .{
    //     info.dwMajorVersion,
    //     info.dwMinorVersion,
    // });
    // return os_string;
    return "Windows";
}

//================= Fetch Host Device =================
pub fn getHostDevice(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxDevice(),
        .Darwin => darwinDevice(arena_allocator),
        else => return error.UnknownDevice,
    };

    return allocator.dupe(u8, result);
}

fn linuxDevice() ![]const u8 {
    // var arena = std.heap.ArenaAllocator.init(allocator);
    // defer arena.deinit();
    // const arena_allocator = arena.allocator();

    // // Check for DMI information
    // const board_vendor = std.fs.readFileToOwnedString(arena_allocator, "/sys/devices/virtual/dmi/id/board_vendor") catch "Unknown";
    // const board_name = std.fs.readFileToOwnedString(arena_allocator, "/sys/devices/virtual/dmi/id/board_name") catch "Unknown";
    // if (!std.mem.eql(u8, board_vendor, "Unknown") or !std.mem.eql(u8, board_name, "Unknown")) {
    //     return std.fmt.allocPrint(allocator, "{s} {s}", .{ board_vendor, board_name });
    // }

    // const product_name = std.fs.readFileToOwnedString(arena_allocator, "/sys/devices/virtual/dmi/id/product_name") catch "Unknown";
    // const product_version = std.fs.file.readFileToOwnedString(arena_allocator, "/sys/devices/virtual/dmi/id/product_version") catch "Unknown";
    // if (!std.mem.eql(u8, product_name, "Unknown") or !std.mem.eql(u8, product_version, "Unknown")) {
    //     return std.fmt.allocPrint(arena_allocator, "{s} {s}", .{ product_name, product_version });
    // }
    // // Check for firmware model
    // const firmware_model = std.fs.readFileToOwnedString(arena_allocator, "/sys/firmware/devicetree/base/model") catch "Unknown";
    // if (!std.mem.eql(u8, firmware_model, "Unknown")) {
    //     return firmware_model;
    // }

    // // Check for temporary model information
    // const tmp_model = std.fs.readFileToOwnedString(arena_allocator, "/tmp/sysinfo/model") catch "Unknown";
    // if (!std.mem.eql(u8, tmp_model, "Unknown")) {
    //     return tmp_model;
    // }

    return "Unknown";
}

fn darwinDevice(allocator: std.mem.Allocator) ![]const u8 {
    return host.getHost(allocator);
}

//================= Fetch Kernel =================
pub fn getKernel(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const result = try switch (getKernelType()) {
        .Linux => linuxKernel(arena_allocator),
        .Darwin => darwinKernel(arena_allocator),
        .BSD => bsdKernel(arena_allocator),
        .Windows => windowsKernel(),
        .Unknown => return error.UnknownKernel,
    };

    return try allocator.dupe(u8, result);
}

fn linuxKernel(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn darwinKernel(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn bsdKernel(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn windowsKernel() ![]const u8 {
    return "TODO";
}

//================= Fetch CPU =================
pub fn getCPU(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxCPU(arena_allocator),
        .Darwin => darwinCPU(arena_allocator),
        .BSD => bsdCPU(arena_allocator),
        .Windows => windowsCPU(),
        .Unknown => return error.UnknownCPU,
    };

    return allocator.dupe(u8, result);
}

fn linuxCPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "lscpu", "-p=cpu" }, "Unknown");
}

fn darwinCPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "machdep.cpu.brand_string" }, "Unknown");
}

fn bsdCPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "hw.model" }, "Unknown");
}

fn windowsCPU() ![]const u8 {
    // const stdout = std.io.getStdOut().writer();
    // var info: std.os.windows.SYSTEM_INFO = undefined;
    // std.os.windows.kernel32.GetSystemInfo(&info);

    // const cpu_string = try std.fmt.allocPrint(allocator, "CPU: {d} cores", .{ info.dwNumberOfProcessors });
    // return cpu_string;
    return "Unknown";
}

//================= Fetch Memory =================
pub fn getMemory(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxMemory(arena_allocator),
        .Darwin => darwinMemory(arena_allocator),
        .BSD => bsdMemory(arena_allocator),
        .Windows => windowsMemory(),
        .Unknown => return error.UnknownMemory,
    };

    return allocator.dupe(u8, result);
}

fn linuxMemory(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "free", "-h" }, "Unknown");
}

fn darwinMemory(allocator: std.mem.Allocator) ![]const u8 {
    const mem_size = try execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "hw.memsize" }, "Unknown");
    const mem_used = try execCommand(allocator, &[_][]const u8{ "bash", "-c", "vm_stat | grep ' active\\|wired ' | sed 's/\\.//g' | awk '{s+=$NF} END {print s}'" }, "Unknown");
    return std.fmt.allocPrint(allocator, "{s} / {s}", .{ mem_used, mem_size });
}

fn bsdMemory(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "hw.physmem" }, "Unknown");
}

fn windowsMemory() ![]const u8 {
    return "TODO";
}

//================= Fetch Uptime =================
pub fn getUptime(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxUptime(arena_allocator),
        .Darwin => darwinUptime(arena_allocator),
        .BSD => bsdUptime(arena_allocator),
        .Windows => windowsUptime(),
        .Unknown => return error.UnknownUptime,
    };

    return try allocator.dupe(u8, result);
}

fn linuxUptime(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uptime", "-p" }, "Unknown");
}

fn darwinUptime(allocator: std.mem.Allocator) ![]const u8 {
    const output = try execCommand(allocator, &[_][]const u8{"uptime"}, "Unknown");
    const start_keyword = " up ";
    const end_keyword = ", ";

    const start = (std.mem.indexOf(u8, output, start_keyword) orelse return error.UptimeNotFound) + start_keyword.len;
    const end = std.mem.indexOf(u8, output[start..], end_keyword) orelse return error.UptimeNotFound;
    const uptime = output[start .. start + end];

    return uptime;
}

fn bsdUptime(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "kern.boottime" }, "Unknown");
}

fn windowsUptime() ![]const u8 {
    return "TODO";
}

//================= Fetch Packages =================
pub fn getPackages(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxPackages(arena_allocator),
        .Darwin => darwinPackages(arena_allocator),
        .BSD => bsdPackages(arena_allocator),
        .Windows => windowsPackages(),
        .Unknown => return error.UnknownPackages,
    };
    return try allocator.dupe(u8, result);
}

fn linuxPackages(allocator: std.mem.Allocator) ![]const u8 {
    return try execCommand(allocator, &[_][]const u8{ "dpkg", "-l" }, "Unknown");
}

fn darwinPackages(allocator: std.mem.Allocator) ![]const u8 {
    return try packages.getMacosPackages(allocator);
}

fn bsdPackages(allocator: std.mem.Allocator) ![]const u8 {
    return try execCommand(allocator, &[_][]const u8{ "pkg", "info" }, "Unknown");
}

fn windowsPackages() ![]const u8 {
    return "TODO";
}

//================= Fetch Shell =================
pub fn getShell(allocator: std.mem.Allocator) ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxShell(allocator),
        .Darwin => darwinShell(allocator),
        .BSD => bsdShell(allocator),
        .Windows => windowsShell(allocator),
        .Unknown => return error.UnknownShell,
    };
}

fn linuxShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "SHELL");
}

fn darwinShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "SHELL");
}

fn bsdShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "SHELL");
}

fn windowsShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "COMSPEC");
}

//================= Fetch Terminal =================
pub fn getTerminal(allocator: std.mem.Allocator) ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxTerminal(allocator),
        .Darwin => darwinTerminal(allocator),
        .BSD => bsdTerminal(allocator),
        .Windows => windowsTerminal(allocator),
        .Unknown => return error.UnknownTerminal,
    };
}

fn linuxTerminal(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "TERM");
}

fn darwinTerminal(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "TERM_PROGRAM");
}

fn bsdTerminal(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "TERM");
}

fn windowsTerminal(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "TERM");
}

//================= Fetch Resolution =================
pub fn getResolution(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxResolution(arena_allocator),
        .Darwin => darwinResolution(arena_allocator),
        .BSD => bsdResolution(arena_allocator),
        .Windows => windowsResolution(),
        .Unknown => return error.UnknownResolution,
    };
    return allocator.dupe(u8, result);
}

fn linuxResolution(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "xdpyinfo", "|", "grep", "dimensions" }, "Unknown");
}

fn darwinResolution(allocator: std.mem.Allocator) ![]const u8 {
    return resolution.getResolution(allocator);
}

fn bsdResolution(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "xdpyinfo", "|", "grep", "dimensions" }, "Unknown");
}

fn windowsResolution() ![]const u8 {
    return "TODO";
}

//================= Fetch DE =================
pub fn getDE(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxDE(arena_allocator),
        .Darwin => darwinDE(),
        .BSD => bsdDE(arena_allocator),
        .Windows => windowsDE(),
        .Unknown => return error.UnknownDE,
    };
    return allocator.dupe(u8, result);
}

fn linuxDE(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn darwinDE() ![]const u8 {
    return "Aqua";
}

fn bsdDE(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn windowsDE() ![]const u8 {
    return "TODO";
}

//================= Fetch WM =================
pub fn getWM(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxWM(arena_allocator),
        .Darwin => darwinWM(arena_allocator),
        .BSD => bsdWM(arena_allocator),
        .Windows => windowsWM(),
        .Unknown => return error.UnknownWM,
    };
    return allocator.dupe(u8, result);
}

fn linuxWM(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn darwinWM(allocator: std.mem.Allocator) ![]const u8 {
    return wm.getMacosWM(allocator) catch {
        return "Call Failed";
    };
}

fn bsdWM(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn windowsWM() ![]const u8 {
    return "TODO";
}

//================= Fetch Theme =================
pub fn getTheme(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxTheme(arena_allocator),
        .Darwin => darwinTheme(arena_allocator),
        .BSD => bsdTheme(arena_allocator),
        .Windows => windowsTheme(),
        .Unknown => return error.UnknownTheme,
    };

    return allocator.dupe(u8, result);
}

fn linuxTheme(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn darwinTheme(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn bsdTheme(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn windowsTheme() ![]const u8 {
    return "TODO";
}

//================= Fetch GPU =================
pub fn getGPU(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxGPU(arena_allocator),
        .Darwin => darwinGPU(arena_allocator),
        .BSD => bsdGPU(arena_allocator),
        .Windows => windowsGPU(),
        .Unknown => return error.UnknownGPU,
    };

    return allocator.dupe(u8, result);
}

fn linuxGPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "lspci", "-v" }, "Unknown");
}

fn darwinGPU(allocator: std.mem.Allocator) ![]const u8 {
    return try gpu.getMacosGPU(allocator);
}

fn bsdGPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "lspci", "-v" }, "Unknown");
}

fn windowsGPU() ![]const u8 {
    return "TODO";
}

//================= Fetch Logo =================
pub fn getLogo(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxLogo(),
        .Darwin => darwinLogo(arena_allocator),
        .BSD => bsdLogo(),
        .Windows => windowsLogo(),
        .Unknown => return error.UnknownLogo,
    };

    return allocator.dupe(u8, result);
}

fn linuxLogo() ![]const u8 {
    // const os_name = execCommand(allocator, &[_][]const u8{ "sw_vers", "-productName" }, "macOS") catch |err| {
    //     std.debug.print("Error executing command: {}\n", .{err});
    //     return "Unknown Linux Distro";
    // };
    // var os_name_lower = try allocator.alloc(u8, os_name.len);
    // var idx: usize = 0;
    // for (os_name) |char| {
    //     os_name_lower[idx] = std.ascii.toLower(char);
    //     idx += 1;
    // }
    // return os_name_lower;
    return "Linux TODO";
}

fn darwinLogo(allocator: std.mem.Allocator) ![]const u8 {
    var cwd_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
    const path = try std.fmt.allocPrint(allocator, "{s}/ascii/macos.txt", .{cwd});
    defer allocator.free(path);
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    return content;
}

fn bsdLogo() ![]const u8 {
    return "TODO";
}

fn windowsLogo() ![]const u8 {
    return "TODO";
}

//================= Fetch Colors =================
pub fn getColors(allocator: std.mem.Allocator) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const result = try switch (getKernelType()) {
        .Linux => linuxColors(),
        .Darwin => darwinColors(arena_allocator),
        .BSD => bsdColors(),
        .Windows => windowsColors(),
        .Unknown => return error.UnknownLogo,
    };

    return allocator.dupe(u8, result);
}

fn linuxColors() ![]const u8 {
    return "TODO";
}

fn darwinColors(allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        try result.appendSlice(try std.fmt.allocPrint(allocator, "\x1b[4{d}m   \x1b[0m", .{i}));
    }

    try result.append('\n');

    i = 0;
    while (i < 8) : (i += 1) {
        try result.appendSlice(try std.fmt.allocPrint(allocator, "\x1b[10{d}m   \x1b[0m", .{i}));
    }

    return result.toOwnedSlice();
}

fn bsdColors() ![]const u8 {
    return "TODO";
}

fn windowsColors() ![]const u8 {
    return "TODO";
}

//================= Fetch Functions =================

pub fn getUsername(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "USER");
}
