const std = @import("std");
const CGDirectDisplayID = u32;
const CGDisplayModeRef = ?*opaque {};
const CVDisplayLinkRef = ?*opaque {};

const CVTime = extern struct {
    timeValue: i64,
    timeScale: i32,
    flags: i32,
};

const kCGErrorSuccess = 0;
const kCVReturnSuccess = 0;
const kCVTimeIsIndefinite = 1 << 0;

extern "c" fn CGGetOnlineDisplayList(maxDisplays: u32, onlineDisplays: [*]CGDirectDisplayID, displayCount: *u32) c_int;
extern "c" fn CGDisplayCopyDisplayMode(display: CGDirectDisplayID) CGDisplayModeRef;
extern "c" fn CGDisplayModeGetRefreshRate(mode: CGDisplayModeRef) f64;
extern "c" fn CGDisplayModeGetPixelWidth(mode: CGDisplayModeRef) usize;
extern "c" fn CGDisplayModeGetPixelHeight(mode: CGDisplayModeRef) usize;
extern "c" fn CGDisplayModeGetWidth(mode: CGDisplayModeRef) usize;
extern "c" fn CGDisplayModeGetHeight(mode: CGDisplayModeRef) usize;
extern "c" fn CGDisplayIsBuiltin(display: CGDirectDisplayID) u32;
extern "c" fn CGDisplayIsMain(display: CGDirectDisplayID) u32;
extern "c" fn CVDisplayLinkCreateWithCGDisplay(displayID: CGDirectDisplayID, displayLinkOut: *CVDisplayLinkRef) c_int;
extern "c" fn CVDisplayLinkGetNominalOutputVideoRefreshPeriod(displayLink: CVDisplayLinkRef) CVTime;

const Display = struct {
    resolution: [2]u32,
    scaled_resolution: ?[2]u32,
    refresh_rate: f64,
    type: []const u8,
    is_main: bool,
};

pub fn getResolution(allocator: std.mem.Allocator) ![]const u8 {
    const displays = try detectDisplayInfo(allocator);

    var result = std.array_list.Managed(u8).init(allocator);

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
    var screens: [128]CGDirectDisplayID = undefined;
    var screen_count: u32 = 0;

    if (CGGetOnlineDisplayList(screens.len, &screens, &screen_count) != kCGErrorSuccess) {
        return error.FailedToGetDisplayList;
    }

    var displays = try std.array_list.Managed(Display).initCapacity(allocator, screen_count);

    for (screens[0..screen_count]) |screen| {
        const mode = CGDisplayCopyDisplayMode(screen);

        if (mode) |display_mode| {
            var refresh_rate = CGDisplayModeGetRefreshRate(display_mode);

            if (refresh_rate == 0) {
                var link: CVDisplayLinkRef = null;
                if (CVDisplayLinkCreateWithCGDisplay(screen, &link) == kCVReturnSuccess) {
                    const time = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(link);
                    if ((time.flags & kCVTimeIsIndefinite) == 0) {
                        refresh_rate = @as(f64, @floatFromInt(time.timeScale)) / @as(f64, @floatFromInt(time.timeValue));
                    }
                }
            }

            const pixel_width = CGDisplayModeGetPixelWidth(display_mode);
            const pixel_height = CGDisplayModeGetPixelHeight(display_mode);
            const width = CGDisplayModeGetWidth(display_mode);
            const height = CGDisplayModeGetHeight(display_mode);

            const scaled_resolution = if (pixel_width != width or pixel_height != height)
                [2]u32{ @intCast(width), @intCast(height) }
            else
                null;

            try displays.append(.{
                .resolution = .{ @intCast(pixel_width), @intCast(pixel_height) },
                .scaled_resolution = scaled_resolution,
                .refresh_rate = refresh_rate,
                .type = if (CGDisplayIsBuiltin(screen) != 0) "Built-in" else "External",
                .is_main = CGDisplayIsMain(screen) != 0,
            });
        }
    }

    return displays.toOwnedSlice();
}
