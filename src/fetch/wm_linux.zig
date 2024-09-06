const std = @import("std");
const mem = std.mem;
const process = std.process;
const fs = std.fs;
const execCommand = @import("../fetch.zig").execCommand;

pub fn getLinuxWM(allocator: mem.Allocator) ![]const u8 {
    if (process.getEnvVarOwned(allocator, "SWAYSOCK")) |_| {
        return allocator.dupe(u8, "sway");
    } else |_| {}

    if (process.getEnvVarOwned(allocator, "HYPRLAND_INSTANCE_SIGNATURE")) |_| {
        return allocator.dupe(u8, "Hyprland");
    } else |_| {}

    if (process.getEnvVarOwned(allocator, "WAYLAND_DISPLAY")) |_| {
        return detectWaylandWM(allocator);
    } else |_| {}

    return detectX11WM(allocator);
}

fn detectWaylandWM(allocator: mem.Allocator) ![]const u8 {
    if (process.getEnvVarOwned(allocator, "XDG_CURRENT_DESKTOP")) |desktop| {
        defer allocator.free(desktop);
        if (mem.eql(u8, desktop, "sway")) {
            return allocator.dupe(u8, "sway");
        }
    } else |_| {}

    const compositors = [_][]const u8{
        "wayfire",
        "weston",
        "mutter",
        "kwin",
    };

    for (compositors) |compositor| {
        if (execCommand(allocator, &[_][]const u8{ compositor, "--version" })) |_| {
            return allocator.dupe(u8, compositor);
        } else |_| {}
    }

    return allocator.dupe(u8, "Unknown Wayland");
}

fn detectX11WM(allocator: mem.Allocator) ![]const u8 {
    const xprop_output = try execCommand(allocator, &[_][]const u8{ "xprop", "-root", "_NET_SUPPORTING_WM_CHECK" });
    defer allocator.free(xprop_output);

    var window_id: u32 = 0;
    {
        var iter = mem.split(u8, xprop_output, " ");
        while (iter.next()) |token| {
            if (std.fmt.parseInt(u32, token, 16)) |id| {
                window_id = id;
                break;
            } else |_| {}
        }
    }

    if (window_id == 0) {
        return error.WindowIDNotFound;
    }

    const wm_name_output = try execCommand(allocator, &[_][]const u8{ "xprop", "-id", try std.fmt.allocPrint(allocator, "0x{X}", .{window_id}), "_NET_WM_NAME" });
    defer allocator.free(wm_name_output);

    var wm_name = mem.trim(u8, wm_name_output, &std.ascii.spaces);
    if (mem.indexOf(u8, wm_name, "=")) |index| {
        wm_name = mem.trim(u8, wm_name[index + 1 ..], &std.ascii.spaces);
    }

    if (wm_name.len >= 2 and wm_name[0] == '"' and wm_name[wm_name.len - 1] == '"') {
        wm_name = wm_name[1 .. wm_name.len - 1];
    }

    return allocator.dupe(u8, wm_name);
}
