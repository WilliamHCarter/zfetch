const std = @import("std");
const builtin = @import("builtin");
const cwin = if (builtin.os.tag == .windows) @cImport({
    @cInclude("windows.h");
}) else undefined;

fn nativeResolution(allocator: std.mem.Allocator) ![]const u8 {
    var display_device = std.mem.zeroes(cwin.DISPLAY_DEVICEW);
    display_device.cb = @sizeOf(cwin.DISPLAY_DEVICEW);

    var dev_mode = std.mem.zeroes(cwin.DEVMODEW);
    dev_mode.dmSize = @sizeOf(cwin.DEVMODEW);

    if (cwin.EnumDisplayDevicesW(null, 0, &display_device, 0) == 0) {
        return error.EnumDisplayDevicesFailed;
    }

    if (cwin.EnumDisplaySettingsW(&display_device.DeviceName, 0xFFFFFFFF, &dev_mode) == 0) {
        return error.EnumDisplaySettingsFailed;
    }

    return try std.fmt.allocPrint(allocator, "{}x{}", .{ dev_mode.dmPelsWidth, dev_mode.dmPelsHeight });
}

fn scaledResolution(allocator: std.mem.Allocator) ![]const u8 {
    const SM_CXSCREEN = 0;
    const SM_CYSCREEN = 1;

    const width = cwin.GetSystemMetrics(SM_CXSCREEN);
    const height = cwin.GetSystemMetrics(SM_CYSCREEN);

    return std.fmt.allocPrint(allocator, "{}x{}", .{ width, height });
}

pub fn windowsResolution(allocator: std.mem.Allocator) ![]const u8 {
    const native = try nativeResolution(allocator);
    const logical = try scaledResolution(allocator);
    const identical: bool = std.mem.eql(u8, native, logical);

    if (identical) {
        return std.fmt.allocPrint(allocator, "{s}", .{native});
    } else {
        return std.fmt.allocPrint(allocator, "{s} (scaled: {s})", .{ native, logical });
    }
}
