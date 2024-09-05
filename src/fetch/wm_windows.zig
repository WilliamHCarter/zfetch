const std = @import("std");
const windows = std.os.windows;
const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const HWND = windows.HWND;

extern "user32" fn GetShellWindow() HWND;
extern "dwmapi" fn DwmIsCompositionEnabled(pfEnabled: *BOOL) BOOL;

pub fn getWindowsWM(allocator: std.mem.Allocator) ![]const u8 {
    var isCompositionEnabled: BOOL = undefined;
    if (DwmIsCompositionEnabled(&isCompositionEnabled) == 0) {
        if (isCompositionEnabled != 0) {
            return std.fmt.allocPrint(allocator, "Desktop Window Manager", .{});
        }
    }

    const shell_window: ?*windows.HWND = null;
    if (shell_window != null) {
        var class_name: [256]u8 = undefined;
        const length = windows.user32.GetClassNameA(shell_window, &class_name, class_name.len);
        if (length > 0) {
            const class_name_slice = class_name[0..length];
            if (std.mem.eql(u8, class_name_slice, "Progman")) {
                return std.fmt.allocPrint(allocator, "Explorer", .{});
            }
        }
    }

    return std.fmt.allocPrint(allocator, "Windows Desktop Environment", .{});
}
