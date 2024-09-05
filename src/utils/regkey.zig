const std = @import("std");
const windows = std.os.windows;

pub fn openRegistryKey(hkey: windows.HKEY, sub_key: [:0]const u16) !windows.HKEY {
    var reg_key: windows.HKEY = undefined;
    const open_res = windows.advapi32.RegOpenKeyExW(
        hkey,
        sub_key,
        0,
        windows.KEY_READ,
        &reg_key,
    );

    if (open_res != 0) {
        return error.UnableToOpenRegistry;
    }

    return reg_key;
}

pub fn queryRegistryValue(allocator: std.mem.Allocator, reg_key: windows.HKEY, value_name: [:0]const u16) ![]const u8 {
    var buffer: [255]u16 = undefined;
    var buffer_size: windows.DWORD = 255 * 2;
    const query_res = windows.advapi32.RegQueryValueExW(
        reg_key,
        value_name,
        null,
        null,
        @as(?*windows.BYTE, @ptrCast(&buffer)),
        &buffer_size,
    );

    if (query_res != 0) {
        return error.UnableToQueryRegistry;
    }

    const result = try std.unicode.utf16LeToUtf8Alloc(allocator, buffer[0 .. buffer_size / 2]);
    return std.mem.trimRight(u8, result, &[_]u8{0});
}

pub fn queryRegistryDword(reg_key: windows.HKEY, value_name: [:0]const u16) !windows.DWORD {
    var buffer: windows.DWORD = undefined;
    var buffer_size: windows.DWORD = @sizeOf(windows.DWORD);
    var value_type: windows.DWORD = undefined;

    const query_res = windows.advapi32.RegQueryValueExW(
        reg_key,
        value_name,
        null,
        &value_type,
        @ptrCast(&buffer),
        &buffer_size,
    );

    if (query_res != 0) {
        return error.UnableToQueryRegistry;
    }

    return buffer;
}
