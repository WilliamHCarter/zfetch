const std = @import("std");
const c = @cImport({
    @cInclude("CoreGraphics/CGDirectDisplay.h");
    @cInclude("CoreVideo/CVDisplayLink.h");
});

const Display = struct {
    resolution: [2]u32,
    scaled_resolution: ?[2]u32,
    refresh_rate: f64,
    type: []const u8,
    is_main: bool,
};

pub fn getResolution(allocator: std.mem.Allocator) ![]const u8 {
    const displays = try detectDisplayInfo(allocator);

    var result = std.ArrayList(u8).init(allocator);

    for (displays) |display| {
        const line = try std.fmt.allocPrint(
            allocator,
            "{d}x{d} @ {d:.2} Hz{s} [{s}]{s}\n",
            .{
                display.resolution[0],
                display.resolution[1],
                display.refresh_rate,
                if (display.scaled_resolution) |scaled|
                    try std.fmt.allocPrint(allocator, " (as {d}x{d})", .{ scaled[0], scaled[1] })
                else
                    "",
                display.type,
                if (display.is_main and displays.len > 1) " [Main]" else "",
            },
        );
        try result.appendSlice(line);
    }

    return result.toOwnedSlice();
}

fn detectDisplayInfo(allocator: std.mem.Allocator) ![]Display {
    var screens: [128]c.CGDirectDisplayID = undefined;
    var screen_count: u32 = 0;

    if (c.CGGetOnlineDisplayList(screens.len, &screens, &screen_count) != c.kCGErrorSuccess) {
        return error.FailedToGetDisplayList;
    }

    var displays = try std.ArrayList(Display).initCapacity(allocator, screen_count);

    for (screens[0..screen_count]) |screen| {
        const mode = c.CGDisplayCopyDisplayMode(screen);

        if (mode) |display_mode| {
            var refresh_rate = c.CGDisplayModeGetRefreshRate(display_mode);

            if (refresh_rate == 0) {
                var link: c.CVDisplayLinkRef = null;
                if (c.CVDisplayLinkCreateWithCGDisplay(screen, &link) == c.kCVReturnSuccess) {
                    const time = c.CVDisplayLinkGetNominalOutputVideoRefreshPeriod(link);
                    if ((time.flags & c.kCVTimeIsIndefinite) == 0) {
                        refresh_rate = @as(f64, @floatFromInt(time.timeScale)) / @as(f64, @floatFromInt(time.timeValue));
                    }
                }
            }

            const pixel_width = c.CGDisplayModeGetPixelWidth(display_mode);
            const pixel_height = c.CGDisplayModeGetPixelHeight(display_mode);
            const width = c.CGDisplayModeGetWidth(display_mode);
            const height = c.CGDisplayModeGetHeight(display_mode);

            const scaled_resolution = if (pixel_width != width or pixel_height != height)
                [2]u32{ @intCast(width), @intCast(height) }
            else
                null;

            try displays.append(.{
                .resolution = .{ @intCast(pixel_width), @intCast(pixel_height) },
                .scaled_resolution = scaled_resolution,
                .refresh_rate = refresh_rate,
                .type = if (c.CGDisplayIsBuiltin(screen) != 0) "Built-in" else "External",
                .is_main = c.CGDisplayIsMain(screen) != 0,
            });
        }
    }

    return displays.toOwnedSlice();
}
