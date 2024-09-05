const std = @import("std");
const windows = std.os.windows;
const regkey = @import("../utils/regkey.zig");

pub fn getWindowsTheme(allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    const dwm_key = std.unicode.utf8ToUtf16LeStringLiteral("Software\\Microsoft\\Windows\\DWM");
    const personalize_key = std.unicode.utf8ToUtf16LeStringLiteral("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");

    const dwm_reg_key = try regkey.openRegistryKey(windows.HKEY_CURRENT_USER, dwm_key);
    defer _ = windows.advapi32.RegCloseKey(dwm_reg_key);

    const personalize_reg_key = try regkey.openRegistryKey(windows.HKEY_CURRENT_USER, personalize_key);
    defer _ = windows.advapi32.RegCloseKey(personalize_reg_key);

    const accent_color_value = std.unicode.utf8ToUtf16LeStringLiteral("AccentColor");
    if (regkey.queryRegistryDword(dwm_reg_key, accent_color_value)) |accent_color| {
        const rgb_color = ((accent_color & 0xFF) << 16) | (accent_color & 0xFF00) | ((accent_color >> 16) & 0xFF);
        try std.fmt.format(result.writer(), "#{X:0>6} ", .{rgb_color});
    } else |_| {
        try result.appendSlice("Custom ");
    }

    const system_theme_value = std.unicode.utf8ToUtf16LeStringLiteral("SystemUsesLightTheme");
    const app_theme_value = std.unicode.utf8ToUtf16LeStringLiteral("AppsUseLightTheme");

    const system_theme = regkey.queryRegistryDword(personalize_reg_key, system_theme_value) catch 0;
    const app_theme = regkey.queryRegistryDword(personalize_reg_key, app_theme_value) catch 0;

    try std.fmt.format(result.writer(), "(System: {s}, Apps: {s})", .{
        if (system_theme == 0) "Dark" else "Light",
        if (app_theme == 0) "Dark" else "Light",
    });

    return result.toOwnedSlice();
}
