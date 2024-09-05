const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const cwin = if (builtin.os.tag == .windows) @cImport({
    @cInclude("windows.h");
}) else undefined;

pub fn getWindowsOS(allocator: std.mem.Allocator) ![]const u8 {
    var version_info: windows.RTL_OSVERSIONINFOW = undefined;
    version_info.dwOSVersionInfoSize = @sizeOf(@TypeOf(version_info));

    const status = windows.ntdll.RtlGetVersion(&version_info);
    if (status != windows.NTSTATUS.SUCCESS) {
        return error.WindowsApiFailed;
    }
    var sysInfo: cwin.SYSTEM_INFO = undefined;
    cwin.GetNativeSystemInfo(&sysInfo);
    const proc_arch = sysInfo.unnamed_0.unnamed_0.wProcessorArchitecture;
    const architecture = getNameFromProcessorArchitecture(proc_arch);

    return std.fmt.allocPrint(allocator, "Windows {d} {s}", .{
        version_info.dwMajorVersion,
        architecture,
    });
}

fn getNameFromProcessorArchitecture(arch: c_int) []const u8 {
    switch (arch) {
        cwin.PROCESSOR_ARCHITECTURE_AMD64 => return "x86_64",
        cwin.PROCESSOR_ARCHITECTURE_ARM => return "ARM",
        cwin.PROCESSOR_ARCHITECTURE_ARM64 => return "ARM64",
        cwin.PROCESSOR_ARCHITECTURE_IA64 => return "Intel Itanium-based",
        cwin.PROCESSOR_ARCHITECTURE_INTEL => return "x86",
        cwin.PROCESSOR_ARCHITECTURE_UNKNOWN => return "Unknown",
        else => return " ",
    }
}
