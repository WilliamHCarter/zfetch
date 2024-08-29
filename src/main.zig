const std = @import("std");
const fetch = @import("fetch.zig");
const layout = @import("layout.zig");

pub fn main() !void {
    const theme_name = "default.txt";
    const theme = try layout.loadTheme("themes/" ++ theme_name);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("Memory leaks detected: {}\n", .{err});
    }

    try layout.render(theme, allocator);
    // const logo = try fetch.getLogo();
    // std.debug.print("{s}", .{logo});
}
