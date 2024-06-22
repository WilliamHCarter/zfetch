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

//================= Fetch Host Device =================
pub fn getHostDevice() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxDevice(),
        .Darwin => darwinDevice(),
        else => return error.UnknownDevice,
    };
}

fn linuxDevice() ![]const u8 {
    // Check for DMI information
    // const board_vendor = std.fs.readFileToOwnedString(std.heap.page_allocator, "/sys/devices/virtual/dmi/id/board_vendor") catch "Unknown";
    // const board_name = std.fs.readFileToOwnedString(std.heap.page_allocator, "/sys/devices/virtual/dmi/id/board_name") catch "Unknown";
    // if (!std.mem.eql(u8, board_vendor, "Unknown") or !std.mem.eql(u8, board_name, "Unknown")) {
    //     return std.fmt.allocPrint(std.heap.page_allocator, "{s} {s}", .{ board_vendor, board_name });
    // }

    // const product_name = std.fs.readFileToOwnedString(std.heap.page_allocator, "/sys/devices/virtual/dmi/id/product_name") catch "Unknown";
    // const product_version = std.fs.file.readFileToOwnedString(std.heap.page_allocator, "/sys/devices/virtual/dmi/id/product_version") catch "Unknown";
    // if (!std.mem.eql(u8, product_name, "Unknown") or !std.mem.eql(u8, product_version, "Unknown")) {
    //     return std.fmt.allocPrint(std.heap.page_allocator, "{s} {s}", .{ product_name, product_version });
    // }
    // // Check for firmware model
    // const firmware_model = std.fs.readFileToOwnedString(std.heap.page_allocator, "/sys/firmware/devicetree/base/model") catch "Unknown";
    // if (!std.mem.eql(u8, firmware_model, "Unknown")) {
    //     return firmware_model;
    // }

    // // Check for temporary model information
    // const tmp_model = std.fs.readFileToOwnedString(std.heap.page_allocator, "/tmp/sysinfo/model") catch "Unknown";
    // if (!std.mem.eql(u8, tmp_model, "Unknown")) {
    //     return tmp_model;
    // }

    return "Unknown";
}

fn darwinDevice() ![]const u8 {
    const kextstat_output: []const u8 = execCommand(std.heap.page_allocator, &[_][]const u8{"kextstat"}, "") catch return "Unknown";
    if (std.mem.indexOf(u8, kextstat_output, "FakeSMC") != null or std.mem.indexOf(u8, kextstat_output, "VirtualSMC") != null) {
        const hw_model = execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.model" }, "") catch return "Unknown";
        return std.fmt.allocPrint(std.heap.page_allocator, "Hackintosh (SMBIOS: {s})", .{hw_model});
    } else {
        return execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.model" }, "") catch return "Unknown";
    }
}

//================= Fetch Kernel =================
pub fn getKernel() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxKernel(),
        .Darwin => darwinKernel(),
        .BSD => bsdKernel(),
        .Windows => windowsKernel(),
        .Unknown => return error.UnknownKernel,
    };
}

fn linuxKernel() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn darwinKernel() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn bsdKernel() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown");
}

fn windowsKernel() ![]const u8 {
    return "TODO";
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
pub fn getMemory() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxMemory(),
        .Darwin => darwinMemory(),
        .BSD => bsdMemory(),
        .Windows => windowsMemory(),
        .Unknown => return error.UnknownMemory,
    };
}

fn linuxMemory() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "free", "-h" }, "Unknown");
}

fn darwinMemory() ![]const u8 {
    const mem_size = try execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.memsize" }, "Unknown");
    const mem_used = try execCommand(std.heap.page_allocator, &[_][]const u8{ "bash", "-c", "vm_stat | grep ' active\\|wired ' | sed 's/\\.//g' | awk '{s+=$NF} END {print s}'" }, "Unknown");
    return std.fmt.allocPrint(std.heap.page_allocator, "{s} / {s}", .{ mem_used, mem_size });
}

fn bsdMemory() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "hw.physmem" }, "Unknown");
}

fn windowsMemory() ![]const u8 {
    return "TODO";
}

//================= Fetch Uptime =================
pub fn getUptime() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxUptime(),
        .Darwin => darwinUptime(),
        .BSD => bsdUptime(),
        .Windows => windowsUptime(),
        .Unknown => return error.UnknownUptime,
    };
}

fn linuxUptime() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "uptime", "-p" }, "Unknown");
}

fn darwinUptime() ![]const u8 {
    const output = try execCommand(std.heap.page_allocator, &[_][]const u8{"uptime"}, "Unknown");
    const start_keyword = " up ";
    const end_keyword = " mins,";

    const start = (std.mem.indexOf(u8, output, start_keyword) orelse return error.UptimeNotFound) + start_keyword.len;
    const end = std.mem.indexOf(u8, output[start..], end_keyword) orelse return error.UptimeNotFound;

    const uptime = output[start .. start + end + end_keyword.len - 1];
    return uptime;
}

fn bsdUptime() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "sysctl", "-n", "kern.boottime" }, "Unknown");
}

fn windowsUptime() ![]const u8 {
    return "TODO";
}

//================= Fetch Packages =================
pub fn getPackages() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxPackages(),
        .Darwin => darwinPackages(),
        .BSD => bsdPackages(),
        .Windows => windowsPackages(),
        .Unknown => return error.UnknownPackages,
    };
}

fn linuxPackages() ![]const u8 {
    return try execCommand(std.heap.page_allocator, &[_][]const u8{ "dpkg", "-l" }, "Unknown");
}

fn darwinPackages() ![]const u8 {
    return try execCommand(std.heap.page_allocator, &[_][]const u8{ "/bin/bash", "-c", "brew list | wc -l" }, "Unknown");
}

fn bsdPackages() ![]const u8 {
    return try execCommand(std.heap.page_allocator, &[_][]const u8{ "pkg", "info" }, "Unknown");
}

fn windowsPackages() ![]const u8 {
    return "TODO";
}

//================= Fetch Shell =================
pub fn getShell() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxShell(),
        .Darwin => darwinShell(),
        .BSD => bsdShell(),
        .Windows => windowsShell(),
        .Unknown => return error.UnknownShell,
    };
}

fn linuxShell() ![]const u8 {
    return fetchEnvVar("SHELL");
}

fn darwinShell() ![]const u8 {
    return fetchEnvVar("SHELL");
}

fn bsdShell() ![]const u8 {
    return fetchEnvVar("SHELL");
}

fn windowsShell() ![]const u8 {
    return fetchEnvVar("COMSPEC");
}

//================= Fetch Terminal =================
pub fn getTerminal() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxTerminal(),
        .Darwin => darwinTerminal(),
        .BSD => bsdTerminal(),
        .Windows => windowsTerminal(),
        .Unknown => return error.UnknownTerminal,
    };
}

fn linuxTerminal() ![]const u8 {
    return fetchEnvVar("TERM");
}

fn darwinTerminal() ![]const u8 {
    return fetchEnvVar("TERM_PROGRAM");
}

fn bsdTerminal() ![]const u8 {
    return fetchEnvVar("TERM");
}

fn windowsTerminal() ![]const u8 {
    return fetchEnvVar("TERM");
}

//================= Fetch Resolution =================
pub fn getResolution() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxResolution(),
        .Darwin => darwinResolution(),
        .BSD => bsdResolution(),
        .Windows => windowsResolution(),
        .Unknown => return error.UnknownResolution,
    };
}

fn linuxResolution() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "xdpyinfo", "|", "grep", "dimensions" }, "Unknown");
}

fn darwinResolution() ![]const u8 {
    const output = try execCommand(std.heap.page_allocator, &[_][]const u8{ "system_profiler", "SPDisplaysDataType" }, "Unknown");
    const start = (std.mem.indexOf(u8, output, "Resolution: ") orelse return error.ResolutionNotFound) + "Resolution: ".len;
    const end = std.mem.indexOf(u8, output[start..], "\n") orelse return error.ResolutionNotFound;
    const resolution = output[start .. start + end];
    return resolution;
}

fn bsdResolution() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "xdpyinfo", "|", "grep", "dimensions" }, "Unknown");
}

fn windowsResolution() ![]const u8 {
    return "TODO";
}

//================= Fetch DE/WM =================
pub fn getDE() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxDE(),
        .Darwin => darwinDE(),
        .BSD => bsdDE(),
        .Windows => windowsDE(),
        .Unknown => return error.UnknownDE,
    };
}

fn linuxDE() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn darwinDE() ![]const u8 {
    return "Aqua";
}

fn bsdDE() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn windowsDE() ![]const u8 {
    return "TODO";
}

//================= Fetch WM =================
pub fn getWM() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxWM(),
        .Darwin => darwinWM(std.heap.page_allocator),
        .BSD => bsdWM(),
        .Windows => windowsWM(),
        .Unknown => return error.UnknownWM,
    };
}

fn linuxWM() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn darwinWM(allocator: std.mem.Allocator) ![]const u8 {
    const wm_commands = &[_][]const u8{
        "ps -e | grep -q '[S]pectacle'",
        "ps -e | grep -q '[A]methyst'",
        "ps -e | grep -q '[k]wm'",
        "ps -e | grep -q '[c]hun[k]wm'",
        "ps -e | grep -q '[y]abai'",
        "ps -e | grep -q '[R]ectangle'",
    };

    const wm_names = &[_][]const u8{
        "Spectacle",
        "Amethyst",
        "Kwm",
        "chunkwm",
        "yabai",
        "Rectangle",
    };

    var i: usize = 0;
    for (wm_commands) |cmd| {
        const result = try execCommand(allocator, &[_][]const u8{ "sh", "-c", cmd }, "failed");
        if (std.mem.eql(u8, result, "failed")) {
            allocator.free(result);
            i += 1;
            continue;
        }
        allocator.free(result);
        return try std.fmt.allocPrint(allocator, "{s}", .{wm_names[i]});
    }

    return "Quartz Compositor";
}

fn bsdWM() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$XDG_CURRENT_DESKTOP" }, "Unknown");
}

fn windowsWM() ![]const u8 {
    return "TODO";
}

//================= Fetch Theme =================
pub fn getTheme() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxTheme(),
        .Darwin => darwinTheme(),
        .BSD => bsdTheme(),
        .Windows => windowsTheme(),
        .Unknown => return error.UnknownTheme,
    };
}

fn linuxTheme() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn darwinTheme() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn bsdTheme() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn windowsTheme() ![]const u8 {
    return "TODO";
}

//================= Fetch GPU =================
pub fn getGPU() ![]const u8 {
    return switch (getKernelType()) {
        .Linux => linuxGPU(),
        .Darwin => darwinGPU(),
        .BSD => bsdGPU(),
        .Windows => windowsGPU(),
        .Unknown => return error.UnknownGPU,
    };
}

fn linuxGPU() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "lspci", "-v" }, "Unknown");
}

fn darwinGPU() ![]const u8 {
    const output = try execCommand(std.heap.page_allocator, &[_][]const u8{ "system_profiler", "SPDisplaysDataType" }, "Unknown");
    const start = (std.mem.indexOf(u8, output, "Chipset Model: ") orelse return error.ResolutionNotFound) + "Chipset Model: ".len;
    const end = std.mem.indexOf(u8, output[start..], "\n") orelse return error.ResolutionNotFound;
    const GPU = output[start .. start + end];
    return GPU;
}

fn bsdGPU() ![]const u8 {
    return execCommand(std.heap.page_allocator, &[_][]const u8{ "lspci", "-v" }, "Unknown");
}

fn windowsGPU() ![]const u8 {
    return "TODO";
}

//================= Fetch Functions =================

pub fn getUsername() ![]const u8 {
    return fetchEnvVar("USER");
}
