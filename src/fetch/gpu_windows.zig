const std = @import("std");
const windows = std.os.windows;
const regkey = @import("../utils/regkey.zig");

pub fn getWindowsGPU(allocator: std.mem.Allocator) ![]const u8 {
    const sub_key = std.unicode.utf8ToUtf16LeStringLiteral("SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}\\0000");
    const value = std.unicode.utf8ToUtf16LeStringLiteral("DriverDesc");

    const reg_key = try regkey.openRegistryKey(windows.HKEY_LOCAL_MACHINE, sub_key);
    defer _ = windows.advapi32.RegCloseKey(reg_key);

    return regkey.queryRegistryValue(allocator, reg_key, value);
}
