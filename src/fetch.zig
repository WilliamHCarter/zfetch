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
const memory = @import("fetch/memory_macos.zig");
const windows = @cImport({
    @cInclude("windows.h");
});
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

fn OSSwitch(allocator: std.mem.Allocator, linux_fn: fn (std.mem.Allocator) anyerror![]const u8, darwin_fn: fn (std.mem.Allocator) anyerror![]const u8, bsd_fn: fn (std.mem.Allocator) anyerror![]const u8, windows_fn: fn (std.mem.Allocator) anyerror![]const u8) ![]const u8 {
    const result: anyerror![]const u8 = switch (builtin.os.tag) {
        .linux => linux_fn(allocator),
        .macos => darwin_fn(allocator),
        .freebsd, .openbsd, .netbsd, .dragonfly => bsd_fn(allocator),
        .windows => windows_fn(allocator),
        else => return error.UnsupportedOS,
    };
    return result;
}

//================= Fetch OS =================
pub fn getOS(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxOS, darwinOS, bsdOS, windowsOS);
}

fn linuxOS(allocator: std.mem.Allocator) ![]const u8 {
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

    return execCommand(allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown") catch "Linux";
}

fn darwinOS(allocator: std.mem.Allocator) ![]const u8 {
    const os_struct = os.parseOS(allocator) catch return "Macos";
    const os_name = os_struct.name;
    const os_version_name = os_struct.version;
    const os_version = os_struct.buildVersion;
    return std.fmt.allocPrint(allocator, "{s} {s} {s}", .{ os_name, os_version_name, os_version }) catch "Macos";
}

fn bsdOS(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uname", "-sr" }, "Unknown") catch "BSD";
}

pub fn windowsOS(allocator: std.mem.Allocator) ![]const u8 {
    var version_info: std.os.windows.RTL_OSVERSIONINFOW = undefined;
    version_info.dwOSVersionInfoSize = @sizeOf(@TypeOf(version_info));

    const status = std.os.windows.ntdll.RtlGetVersion(&version_info);
    if (status != std.os.windows.NTSTATUS.SUCCESS) {
        return error.WindowsApiFailed;
    }

    return std.fmt.allocPrint(allocator, "Windows {d}.{d}.{d}", .{
        version_info.dwMajorVersion,
        version_info.dwMinorVersion,
        version_info.dwBuildNumber,
    });
}

//================= Fetch Host Device =================
pub fn getHostDevice(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxDevice, darwinDevice, bsdDevice, windowsDevice);
}

fn linuxDevice(allocator: std.mem.Allocator) ![]const u8 {

    // // Check for DMI information
    // const board_vendor = std.fs.readFileToOwnedString(allocator, "/sys/devices/virtual/dmi/id/board_vendor") catch "Unknown";
    // const board_name = std.fs.readFileToOwnedString(allocator, "/sys/devices/virtual/dmi/id/board_name") catch "Unknown";
    // if (!std.mem.eql(u8, board_vendor, "Unknown") or !std.mem.eql(u8, board_name, "Unknown")) {
    //     return std.fmt.allocPrint(allocator, "{s} {s}", .{ board_vendor, board_name });
    // }

    // const product_name = std.fs.readFileToOwnedString(allocator, "/sys/devices/virtual/dmi/id/product_name") catch "Unknown";
    // const product_version = std.fs.file.readFileToOwnedString(allocator, "/sys/devices/virtual/dmi/id/product_version") catch "Unknown";
    // if (!std.mem.eql(u8, product_name, "Unknown") or !std.mem.eql(u8, product_version, "Unknown")) {
    //     return std.fmt.allocPrint(allocator, "{s} {s}", .{ product_name, product_version });
    // }
    // // Check for firmware model
    // const firmware_model = std.fs.readFileToOwnedString(allocator, "/sys/firmware/devicetree/base/model") catch "Unknown";
    // if (!std.mem.eql(u8, firmware_model, "Unknown")) {
    //     return firmware_model;
    // }

    // // Check for temporary model information
    // const tmp_model = std.fs.readFileToOwnedString(allocator, "/tmp/sysinfo/model") catch "Unknown";
    // if (!std.mem.eql(u8, tmp_model, "Unknown")) {
    //     return tmp_model;
    // }

    return execCommand(allocator, &[_][]const u8{ "uname", "-m" }, "Unknown");
}

fn darwinDevice(allocator: std.mem.Allocator) ![]const u8 {
    return host.getHost(allocator);
}

fn bsdDevice(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "uname", "-m" }, "Unknown");
}

fn windowsDevice(allocator: std.mem.Allocator) ![]const u8 {
    // var system_info: c.SYSTEM_INFO = undefined;
    // c.GetSystemInfo(&system_info);

    // const name = getNameFromProcessorArchitecture(system_info.wProcessorArchitecture) orelse "Unknown";
    const name = "windows";
    return try std.fmt.allocPrint(allocator, "Windows Device with Processor Architecture: {s}", .{name});
}

fn getNameFromProcessorArchitecture(arch: []const u8) ?[]const u8 {
    // switch (arch) {
    //     c.PROCESSOR_ARCHITECTURE_AMD64 => return "x64 (AMD or Intel)",
    //     c.PROCESSOR_ARCHITECTURE_ARM => return "ARM",
    //     c.PROCESSOR_ARCHITECTURE_ARM64 => return "ARM64",
    //     c.PROCESSOR_ARCHITECTURE_IA64 => return "Intel Itanium-based",
    //     c.PROCESSOR_ARCHITECTURE_INTEL => return "x86",
    //     c.PROCESSOR_ARCHITECTURE_UNKNOWN => return "Unknown",
    //     else => return null,
    // }
    if (arch.len() == 0) {
        return "Windows";
    }
    return null;
}

//================= Fetch Kernel =================
pub fn getKernel(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxKernel, darwinKernel, bsdKernel, windowsKernel);
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

fn windowsKernel(allocator: std.mem.Allocator) ![]const u8 {
    var version_info: std.os.windows.RTL_OSVERSIONINFOW = undefined;
    version_info.dwOSVersionInfoSize = @sizeOf(@TypeOf(version_info));

    const status = std.os.windows.ntdll.RtlGetVersion(&version_info);
    if (status != std.os.windows.NTSTATUS.SUCCESS) {
        return error.WindowsApiFailed;
    }

    return std.fmt.allocPrint(allocator, "Windows NT {d}.{d}.{d}", .{
        version_info.dwMajorVersion,
        version_info.dwMinorVersion,
        version_info.dwBuildNumber,
    });
}

//================= Fetch CPU =================
pub fn getCPU(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxCPU, darwinCPU, bsdCPU, windowsCPU);
}

fn linuxCPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "lscpu", "-p=cpu" }, "Unknown");
}

fn darwinCPU(allocator: std.mem.Allocator) ![]const u8 {
    return host.sysctlGetString(allocator, "machdep.cpu.brand_string");
}

fn bsdCPU(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "hw.model" }, "Unknown");
}

fn windowsCPU(allocator: std.mem.Allocator) ![]const u8 {
    const sub_key = std.unicode.utf8ToUtf16LeStringLiteral("HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0");
    const value = std.unicode.utf8ToUtf16LeStringLiteral("ProcessorNameString");
    var reg_key: std.os.windows.HKEY = undefined;

    const open_res = std.os.windows.advapi32.RegOpenKeyExW(
        std.os.windows.HKEY_LOCAL_MACHINE,
        sub_key,
        0,
        std.os.windows.KEY_READ,
        &reg_key,
    );

    if (open_res != 0) {
        return error.UnableToOpenRegistry;
    }

    var cpu: [255]u16 = undefined;
    var cpu_size: windows.DWORD = std.os.windows.NAME_MAX;
    const query_res = std.os.windows.advapi32.RegQueryValueExW(reg_key, value, null, null, @as(?*std.os.windows.BYTE, @ptrCast(&cpu)), &cpu_size);

    _ = std.os.windows.advapi32.RegCloseKey(reg_key);

    if (query_res != windows.ERROR_SUCCESS) {
        return error.UnableToOpenRegistry;
    }

    const result = std.unicode.utf16LeToUtf8Alloc(allocator, &cpu) catch "";
    const index = std.mem.indexOf(u16, &cpu, &[_]u16{0}) orelse cpu.len;
    return std.fmt.allocPrint(allocator, "{s}", .{result[0..index]});
}
//================= Fetch Memory =================
pub fn getMemory(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxMemory, darwinMemory, bsdMemory, windowsMemory);
}

fn linuxMemory(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "free", "-h" }, "Unknown");
}

fn darwinMemory(allocator: std.mem.Allocator) ![]const u8 {
    const mem_size = try execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "hw.memsize" }, "Unknown");
    const mem_used = try memory.getMachMemoryStats();
    return std.fmt.allocPrint(allocator, "{d} / {s}", .{ mem_used, mem_size });
}

fn bsdMemory(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "hw.physmem" }, "Unknown");
}

fn windowsMemory(allocator: std.mem.Allocator) ![]const u8 {
    // var memory_status: c.MEMORYSTATUSEX = undefined;
    // memory_status.dwLength = @sizeOf(c.MEMORYSTATUSEX);
    // if (c.GlobalMemoryStatusEx(&memory_status) == 0) {
    //     return error.MemoryStatusFailed;
    // }

    // const totalPhysMB = memory_status.ullTotalPhys / (1024 * 1024);
    // const availPhysMB = memory_status.ullAvailPhys / (1024 * 1024);
    // const usedPhysMB = totalPhysMB - availPhysMB;

    // return try std.fmt.allocPrint(allocator, "{d} / {d}", .{ usedPhysMB, totalPhysMB });
    return std.fmt.allocPrint(allocator, "Windows", .{});
}

//================= Fetch Uptime =================
pub fn getUptime(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxUptime, darwinUptime, bsdUptime, windowsUptime);
}

fn formatUptime(allocator: std.mem.Allocator, uptime_seconds: u64) ![]const u8 {
    const days = uptime_seconds / (24 * 60 * 60);
    const hours = (uptime_seconds % (24 * 60 * 60)) / (60 * 60);
    const minutes = (uptime_seconds % (60 * 60)) / 60;

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    if (days > 0) {
        try result.writer().print("{d} day{s}", .{ days, if (days == 1) "" else "s" });
    }

    if (hours > 0) {
        if (result.items.len > 0) try result.appendSlice(", ");
        try result.writer().print("{d} hour{s}", .{ hours, if (hours == 1) "" else "s" });
    }

    if (minutes > 0 or (days == 0 and hours == 0)) {
        if (result.items.len > 0) try result.appendSlice(", ");
        try result.writer().print("{d} min{s}", .{ minutes, if (minutes == 1) "" else "s" });
    }

    return result.toOwnedSlice();
}

fn getBootTime(allocator: std.mem.Allocator) !i64 {
    const output = try execCommand(allocator, &[_][]const u8{ "sysctl", "-n", "kern.boottime" }, "Unknown");
    defer allocator.free(output);
    var iter = std.mem.split(u8, output, "=");
    _ = iter.next();
    const boot_time_str = iter.next() orelse return error.BootTimeNotFound;

    const comma_index = std.mem.indexOf(u8, boot_time_str, ",") orelse return error.InvalidBootTimeFormat;
    const clean_boot_time_str = std.mem.trim(u8, boot_time_str[0..comma_index], " ");

    return try std.fmt.parseInt(i64, clean_boot_time_str, 10);
}

fn linuxUptime(allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.openFileAbsolute("/proc/uptime", .{});
    defer file.close();

    var buffer: [100]u8 = undefined;
    const bytes_read = try file.read(&buffer);
    const content = buffer[0..bytes_read];

    var iter = std.mem.split(u8, content, " ");
    const uptime_str = iter.next() orelse return error.InvalidUptimeFormat;
    const uptime_seconds_f64 = try std.fmt.parseFloat(f64, uptime_str);
    const uptime_seconds: u64 = @intFromFloat(uptime_seconds_f64);
    const formatted_uptime = try formatUptime(allocator, uptime_seconds);
    return try allocator.dupe(u8, formatted_uptime);
}

fn darwinUptime(allocator: std.mem.Allocator) ![]const u8 {
    const boot_time = try getBootTime(allocator);
    const current_time = std.time.timestamp();
    if (current_time < boot_time) return error.InvalidBootTime;

    const uptime_seconds: u64 = @intCast(current_time - boot_time);
    return formatUptime(allocator, uptime_seconds);
}

fn bsdUptime(allocator: std.mem.Allocator) ![]const u8 {
    const boot_time = try getBootTime(allocator);
    const current_time = std.time.timestamp();
    if (current_time < boot_time) return error.InvalidBootTime;

    const uptime_seconds: u64 = @intCast(current_time - boot_time);
    return formatUptime(allocator, uptime_seconds);
}

fn windowsUptime(allocator: std.mem.Allocator) ![]const u8 {
    const uptime_milliseconds = windows.GetTickCount64();
    const uptime_seconds: u64 = uptime_milliseconds / 1000;

    return formatUptime(allocator, uptime_seconds);
}

//================= Fetch Packages =================
pub fn getPackages(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxPackages, darwinPackages, bsdPackages, windowsPackages);
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

fn windowsPackages(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "Windows", .{});
}

//================= Fetch Shell =================
pub fn getShell(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxShell, darwinShell, bsdShell, windowsShell);
}

fn linuxShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "SHELL");
}

const ShellType = struct {
    name: []const u8,
    command: []const u8,
    trim: []const u8,
};

fn shellTrim(shell: ShellType, version: []const u8) ![]const u8 {
    if (std.mem.eql(u8, shell.trim, "none")) {
        return version;
    } else if (std.mem.eql(u8, shell.trim, "dash")) {
        if (std.mem.indexOfScalar(u8, version, '-')) |dash_index| {
            return version[0..dash_index];
        }
    } else if (std.mem.eql(u8, shell.trim, "ksh")) {
        var trimmed = std.mem.trim(u8, version, " KSH");
        trimmed = std.mem.trimLeft(u8, trimmed, "version ");
        return trimmed;
    }
    return version;
}

pub fn darwinShell(allocator: std.mem.Allocator) ![]const u8 {
    const shells = [_]ShellType{
        .{ .name = "bash", .command = "echo $BASH_VERSION", .trim = "dash" },
        .{ .name = "zsh", .command = "echo $ZSH_VERSION", .trim = "none" },
        .{ .name = "ksh", .command = "echo $KSH_VERSION", .trim = "ksh" },
        .{ .name = "fish", .command = "echo $FISH_VERSION", .trim = "none" },
    };

    const shell_path = try std.process.getEnvVarOwned(allocator, "SHELL");
    defer allocator.free(shell_path);
    const shell_name = std.fs.path.basename(shell_path);

    for (shells) |shell| {
        if (std.mem.eql(u8, shell_name, shell.name)) {
            const version = try execCommand(allocator, &.{ shell_path, "-c", shell.command }, "Unknown");
            defer allocator.free(version);
            const trimmed_version = try shellTrim(shell, version);
            defer allocator.free(trimmed_version);
            return try std.fmt.allocPrint(allocator, "{s} {s}", .{ shell_name, trimmed_version });
        }
    }

    const version = try execCommand(allocator, &.{ shell_path, "--version" }, "Unknown");
    defer allocator.free(version);

    return try std.fmt.allocPrint(allocator, "{s} {s}", .{ shell_name, version });
}

fn bsdShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "SHELL");
}

fn windowsShell(allocator: std.mem.Allocator) ![]const u8 {
    return fetchEnvVar(allocator, "COMSPEC");
}

//================= Fetch Terminal =================
pub fn getTerminal(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxTerminal, darwinTerminal, bsdTerminal, windowsTerminal);
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
    return OSSwitch(allocator, linuxResolution, darwinResolution, bsdResolution, windowsResolution);
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

fn windowsResolution(allocator: std.mem.Allocator) ![]const u8 {
    // const hdc = c.GetDC(null);
    // if (hdc == null) return error.FailedToGetDC;

    // const width = c.GetDeviceCaps(hdc, c.HORZRES);
    // const height = c.GetDeviceCaps(hdc, c.VERTRES);

    // _ = c.ReleaseDC(null, hdc);

    // return std.fmt.allocPrint(allocator, "{d} x {d}", .{ width, height });
    return std.fmt.allocPrint(allocator, "Windows", .{});
}

//================= Fetch DE =================
pub fn getDE(allocator: std.mem.Allocator) ![]const u8 {
    const result = try switch (getKernelType()) {
        .Linux => linuxDE(allocator),
        .Darwin => darwinDE(),
        .BSD => bsdDE(allocator),
        .Windows => windowsDE(),
        .Unknown => return error.UnknownDE,
    };
    return result;
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
    return OSSwitch(allocator, linuxWM, darwinWM, bsdWM, windowsWM);
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

fn windowsWM(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "TODO", .{});
}

//================= Fetch Theme =================
pub fn getTheme(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxTheme, darwinTheme, bsdTheme, windowsTheme);
}

fn linuxTheme(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn darwinTheme(allocator: std.mem.Allocator) ![]const u8 {
    const global_preferences = try std.fs.path.join(allocator, &[_][]const u8{
        fetchEnvVar(allocator, "HOME"),
        "Library",
        "Preferences",
        ".GlobalPreferences.plist",
    });

    const wm_theme = execCommand(allocator, &[_][]const u8{ "/usr/libexec/PlistBuddy", "-c", "Print AppleInterfaceStyle", global_preferences }, "Light");
    const wm_theme_color_str = execCommand(allocator, &[_][]const u8{ "/usr/libexec/PlistBuddy", "-c", "Print AppleAccentColor", global_preferences, "2>/dev/null" }, "-2");
    const theme = wm_theme catch "Light";
    const color_str = wm_theme_color_str catch "-2";
    const color = switch (std.fmt.parseInt(i32, color_str, 10) catch -2) {
        -1 => "Graphite",
        0 => "Red",
        1 => "Orange",
        2 => "Yellow",
        3 => "Green",
        5 => "Purple",
        6 => "Pink",
        else => "Blue",
    };

    var result = std.ArrayList(u8).init(allocator);
    try result.appendSlice(color);
    try result.appendSlice(" (");
    try result.appendSlice(theme);
    try result.appendSlice(")");
    return result.toOwnedSlice();
}

fn bsdTheme(allocator: std.mem.Allocator) ![]const u8 {
    return execCommand(allocator, &[_][]const u8{ "echo", "$GTK_THEME" }, "Unknown");
}

fn windowsTheme(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "TODO", .{});
}

//================= Fetch GPU =================
pub fn getGPU(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxGPU, darwinGPU, bsdGPU, windowsGPU);
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

fn windowsGPU(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "TODO", .{});
}

//================= Fetch Logo =================
pub fn getLogo(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxLogo, darwinLogo, bsdLogo, windowsLogo);
}

fn linuxLogo(allocator: std.mem.Allocator) ![]const u8 {
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
    return std.fmt.allocPrint(allocator, "TODO", .{});
}

fn darwinLogo(allocator: std.mem.Allocator) ![]const u8 {
    var cwd_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
    const path = try std.fmt.allocPrint(allocator, "{s}/ascii/macos.txt", .{cwd});
    defer allocator.free(path);
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    return content;
}

fn bsdLogo(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "TODO", .{});
}

fn windowsLogo(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "TODO", .{});
}

//================= Fetch Colors =================
pub fn getColors(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, linuxColors, darwinColors, bsdColors, windowsColors);
}

fn ansiColors(allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    try result.append('\n');

    for (0..8) |i| {
        try result.appendSlice(try std.fmt.allocPrint(allocator, "\x1b[4{d}m   ", .{i}));
    }
    try result.appendSlice(try std.fmt.allocPrint(allocator, "\x1b[0m", .{}));

    try result.append('\n');
    for (0..8) |i| {
        try result.appendSlice(try std.fmt.allocPrint(allocator, "\x1b[10{d}m   ", .{i}));
    }
    try result.appendSlice(try std.fmt.allocPrint(allocator, "\x1b[0m", .{}));

    return result.toOwnedSlice();
}

fn linuxColors(allocator: std.mem.Allocator) ![]const u8 {
    return ansiColors(allocator);
}

fn darwinColors(allocator: std.mem.Allocator) ![]const u8 {
    return ansiColors(allocator);
}

fn bsdColors(allocator: std.mem.Allocator) ![]const u8 {
    return ansiColors(allocator);
}

fn windowsColors(allocator: std.mem.Allocator) ![]const u8 {
    return ansiColors(allocator);
}

pub fn getUsername(allocator: std.mem.Allocator) ![]const u8 {
    return OSSwitch(allocator, UsernamePosix, UsernamePosix, UsernamePosix, UsernameWindows);
}

pub fn UsernamePosix(allocator: std.mem.Allocator) ![]const u8 {
    const username = fetchEnvVar(allocator, "USER");
    defer allocator.free(username);

    var hostname_buffer: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&hostname_buffer);

    return try std.fmt.allocPrint(allocator, "{s}@{s}", .{ username, hostname });
}

pub fn UsernameWindows(allocator: std.mem.Allocator) ![]const u8 {
    const username = fetchEnvVar(allocator, "USER");
    //defer allocator.free(username);

    return try std.fmt.allocPrint(allocator, "{s}", .{username});
}
