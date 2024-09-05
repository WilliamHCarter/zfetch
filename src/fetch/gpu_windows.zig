const std = @import("std");
const windows = std.os.windows;

pub fn getWindowsGPU(allocator: std.mem.Allocator) ![]const u8 {
    const sub_key = std.unicode.utf8ToUtf16LeStringLiteral("SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}\\0000");
    const value = std.unicode.utf8ToUtf16LeStringLiteral("DriverDesc");
    var reg_key: windows.HKEY = undefined;

    const open_res = windows.advapi32.RegOpenKeyExW(
        windows.HKEY_LOCAL_MACHINE,
        sub_key,
        0,
        windows.KEY_READ,
        &reg_key,
    );

    if (open_res != 0) {
        return error.UnableToOpenRegistry;
    }
    defer _ = windows.advapi32.RegCloseKey(reg_key);

    var gpu: [255]u16 = undefined;
    var gpu_size: windows.DWORD = 255 * 2;
    const query_res = windows.advapi32.RegQueryValueExW(reg_key, value, null, null, @as(?*windows.BYTE, @ptrCast(&gpu)), &gpu_size);

    if (query_res != 0) {
        return error.UnableToQueryRegistry;
    }

    const result = try std.unicode.utf16LeToUtf8Alloc(allocator, gpu[0 .. gpu_size / 2]);
    return std.mem.trimRight(u8, result, &[_]u8{0});
}
