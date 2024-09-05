const std = @import("std");
const windows = std.os.windows;

pub fn getWindowsTheme(allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    const dwm_key = std.unicode.utf8ToUtf16LeStringLiteral("Software\\Microsoft\\Windows\\DWM");
    var accent_color: windows.DWORD = undefined;
    if (try getRegistryDword(windows.HKEY_CURRENT_USER, dwm_key, "AccentColor", &accent_color)) {
        const rgb_color = ((accent_color & 0xFF) << 16) | (accent_color & 0xFF00) | ((accent_color >> 16) & 0xFF);
        try std.fmt.format(result.writer(), "#{X:0>6} ", .{rgb_color});
    } else {
        try result.appendSlice("Custom ");
    }

    const personalize_key = std.unicode.utf8ToUtf16LeStringLiteral("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");
    var system_theme: windows.DWORD = undefined;
    var app_theme: windows.DWORD = undefined;

    const system_theme_success = try getRegistryDword(windows.HKEY_CURRENT_USER, personalize_key, "SystemUsesLightTheme", &system_theme);
    const app_theme_success = try getRegistryDword(windows.HKEY_CURRENT_USER, personalize_key, "AppsUseLightTheme", &app_theme);

    if (system_theme_success and app_theme_success) {
        try std.fmt.format(result.writer(), "(System: {s}, Apps: {s})", .{
            if (system_theme == 0) "Dark" else "Light",
            if (app_theme == 0) "Dark" else "Light",
        });
    }

    return result.toOwnedSlice();
}

fn getRegistryDword(hkey: windows.HKEY, sub_key: [:0]const u16, value_name: [:0]const u8, out: *windows.DWORD) !bool {
    var reg_key: windows.HKEY = undefined;
    const open_res = windows.advapi32.RegOpenKeyExW(hkey, sub_key, 0, windows.KEY_READ, &reg_key);
    if (open_res != 0) {
        return false;
    }
    defer _ = windows.advapi32.RegCloseKey(reg_key);

    var buffer_size: windows.DWORD = @sizeOf(windows.DWORD);
    var value_type: windows.DWORD = undefined;
    const value_name_w = try std.unicode.utf8ToUtf16LeWithNull(std.heap.page_allocator, value_name);
    defer std.heap.page_allocator.free(value_name_w);

    const query_res = windows.advapi32.RegQueryValueExW(
        reg_key,
        value_name_w,
        null,
        &value_type,
        @ptrCast(out),
        &buffer_size,
    );

    return query_res == 0;
}
