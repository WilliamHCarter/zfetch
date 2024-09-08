const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const ArrayList = std.ArrayList;
const execCommand = @import("../fetch.zig").execCommand;

pub fn getLinuxWM(allocator: mem.Allocator) ![]const u8 {
    var wm: []const u8 = undefined;
    if (isWayland()) {
        wm = try getWaylandWM(allocator);
    } else {
        wm = try getX11WM(allocator);
    }
    return renameWM(allocator, wm);
}

fn isWayland() bool {
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "WAYLAND_DISPLAY")) |wayland_display| {
        defer std.heap.page_allocator.free(wayland_display);
        return wayland_display.len > 0;
    } else |_| {
        return false;
    }
}

fn getWaylandWM(allocator: mem.Allocator) ![]const u8 {
    const wayland_wms = [_][]const u8{
        "arcan",      "asc",      "cage",    "cardboard", "clayland",   "cosmic-comp", "dwc",     "dwl",      "fireplace", "gnome-shell",
        "greenfield", "grefsen",  "hikari",  "hyprland",  "japokwm",    "kwin",        "labwc",   "lipstick", "maynard",   "mazecompositor",
        "motorcar",   "newm",     "orbital", "orbment",   "perceptia",  "phosh",       "river",   "rustland", "sway",      "swayfx",
        "ulubis",     "velox",    "wavy",    "waybox",    "way-cooler", "waydroid",    "wayfire", "wayhouse", "wayland",   "waymonad",
        "westeros",   "westford", "weston",  "wdisplays", "wio",
    };

    const process_list = try execCommand(allocator, &[_][]const u8{ "ps", "-e" }, "");
    for (wayland_wms) |wm| {
        if (std.mem.indexOf(u8, process_list, wm)) |_| {
            return try allocator.dupe(u8, wm);
        }
    }

    const socket_path = try getWaylandSocketPath(allocator);
    const lsof_pid = try execCommand(allocator, &[_][]const u8{ "lsof", "-t", socket_path }, "");
    if (lsof_pid.len > 0) {
        return try getProcessName(allocator, lsof_pid);
    }

    const fuser_pid = try execCommand(allocator, &[_][]const u8{ "fuser", socket_path }, "");
    if (fuser_pid.len > 0) {
        return try getProcessName(allocator, fuser_pid);
    }

    return error.WaylandWMNotFound;
}

fn getX11WM(allocator: mem.Allocator) ![]const u8 {
    const x11_wms = [_][]const u8{ "sowm", "catwm", "fvwm", "dwm", "2bwm", "monsterwm", "tinywm", "x11fs", "xmonad", "awesome", "bspwm", "budgie-wm", "cinnamon", "compiz", "deepin-wm", "enlightenment", "fluxbox", "i3", "icewm", "jwm", "marco", "metacity", "muffin", "mutter", "openbox", "pekwm", "qtile", "ratpoison", "sawfish", "spectrwm", "stumpwm", "subtle", "twm", "windowmaker", "wmaker", "wmii", "xfwm4", "xmonad" };

    const process_list = try execCommand(allocator, &[_][]const u8{ "ps", "-e" }, "");
    for (x11_wms) |wm| {
        if (std.mem.indexOf(u8, process_list, wm)) |_| {
            return try allocator.dupe(u8, wm);
        }
    }

    return try getX11WMUsingXprop(allocator);
}

fn getX11WMUsingXprop(allocator: mem.Allocator) ![]const u8 {
    const xprop_output = try execCommand(allocator, &[_][]const u8{ "xprop", "-root", "-notype", "_NET_SUPPORTING_WM_CHECK" }, "");

    var window_id_iter = std.mem.split(u8, xprop_output, "# ");
    const window_id = window_id_iter.next().?;

    const wm_name_output = try execCommand(allocator, &[_][]const u8{ "xprop", "-id", window_id, "-notype", "-len", "100", "-f", "_NET_WM_NAME", "8t" }, "");

    var wm_name_iter = std.mem.split(u8, wm_name_output, "= ");
    var wm_name = wm_name_iter.next().?;

    wm_name = std.mem.trim(u8, wm_name, "\"");

    return try allocator.dupe(u8, wm_name);
}

fn getWaylandSocketPath(allocator: mem.Allocator) ![]const u8 {
    const xdg_runtime_dir = try std.process.getEnvVarOwned(allocator, "XDG_RUNTIME_DIR");
    const wayland_display = try std.process.getEnvVarOwned(allocator, "WAYLAND_DISPLAY");

    return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ xdg_runtime_dir, wayland_display });
}

fn getProcessName(allocator: mem.Allocator, pid: []const u8) ![]const u8 {
    return try execCommand(allocator, &[_][]const u8{ "ps", "-p", pid, "-o", "comm=" }, "");
}

fn renameWM(allocator: mem.Allocator, wm: []const u8) ![]const u8 {
    const lowercased = try std.ascii.allocLowerString(allocator, wm);

    if (std.mem.indexOf(u8, lowercased, "windowmaker") != null) {
        return try allocator.dupe(u8, "wmaker");
    } else if (std.mem.indexOf(u8, lowercased, "gnome") != null and std.mem.indexOf(u8, lowercased, "shell") != null) {
        return try allocator.dupe(u8, "Mutter");
    } else {
        return try allocator.dupe(u8, wm);
    }
}
