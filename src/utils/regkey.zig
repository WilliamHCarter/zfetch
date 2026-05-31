const std = @import("std");
const windows = std.os.windows;
const KEY_READ: windows.DWORD = 0x00020019;

extern "advapi32" fn RegOpenKeyExW(hKey: windows.HKEY, lpSubKey: [*:0]const u16, ulOptions: windows.DWORD, samDesired: windows.DWORD, phkResult: *windows.HKEY) windows.LSTATUS;
extern "advapi32" fn RegQueryValueExW(hKey: windows.HKEY, lpValueName: [*:0]const u16, lpReserved: ?*windows.DWORD, lpType: ?*windows.DWORD, lpData: ?*windows.BYTE, lpcbData: *windows.DWORD) windows.LSTATUS;
extern "advapi32" fn RegCloseKey(hKey: windows.HKEY) windows.LSTATUS;

pub fn closeRegistryKey(hkey: windows.HKEY) windows.LSTATUS {
    return RegCloseKey(hkey);
}

pub fn openRegistryKey(hkey: windows.HKEY, sub_key: [:0]const u16) !windows.HKEY {
    var reg_key: windows.HKEY = undefined;
    const open_res = RegOpenKeyExW(
        hkey,
        sub_key,
        0,
        KEY_READ,
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
    const query_res = RegQueryValueExW(
        reg_key,
        value_name,
        null,
        null,
        @ptrCast(&buffer),
        &buffer_size,
    );

    if (query_res != 0) {
        return error.UnableToQueryRegistry;
    }

    const result = try std.unicode.utf16LeToUtf8Alloc(allocator, buffer[0 .. buffer_size / 2]);
    return std.mem.trimEnd(u8, result, &[_]u8{0});
}

pub fn queryRegistryDword(reg_key: windows.HKEY, value_name: [:0]const u16) !windows.DWORD {
    var buffer: windows.DWORD = undefined;
    var buffer_size: windows.DWORD = @sizeOf(windows.DWORD);
    var value_type: windows.DWORD = undefined;

    const query_res = RegQueryValueExW(
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
