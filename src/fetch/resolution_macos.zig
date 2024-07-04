const std = @import("std");
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
});

pub fn getResolution(allocator: std.mem.Allocator) ![]const u8 {
    const main_display = c.CGMainDisplayID();
    const bounds = c.CGDisplayBounds(main_display);

    const width = @as(u32, @intFromFloat(bounds.size.width));
    const height = @as(u32, @intFromFloat(bounds.size.height));

    return try std.fmt.allocPrint(allocator, "{}x{}", .{ width, height });
}
