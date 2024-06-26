//==================================================================================================
// File:       layout.zig
// Contents:   System for rendering fetched info based on theme file preferences.
// Author:     Will Carter
//==================================================================================================
const std = @import("std");
const fetch = @import("fetch.zig");

//=========================== Data Structures ===========================
pub const Component = struct {
    kind: ComponentKind,
    properties: std.StringHashMap([]const u8),

    fn init(kind: ComponentKind) Component {
        return .{
            .kind = kind,
            .properties = std.StringHashMap([]const u8).init(std.heap.page_allocator),
        };
    }

    fn deinit(self: *Component) void {
        self.properties.deinit();
    }
};

const ComponentKind = enum {
    Username,
    OS,
    Hostname,
    Kernel,
    Uptime,
    Packages,
    Shell,
    Terminal,
    Resolution,
    DE,
    WM,
    Theme,
    CPU,
    GPU,
    Memory,
    TopBar,
};

const Theme = struct {
    name: []const u8,
    components: std.ArrayList(Component),

    fn init(name: []const u8) Theme {
        return .{
            .name = name,
            .components = std.ArrayList(Component).init(std.heap.page_allocator),
        };
    }

    fn deinit(self: *Theme) void {
        for (self.components.items) |*component| {
            component.deinit();
        }
        self.components.deinit();
    }
};

//=========================== Parsing ===========================

pub fn loadTheme(name: []const u8) !Theme {
    var cwd_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
    const path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{ cwd, name });
    defer std.heap.page_allocator.free(path);

    const content = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, path, 1024 * 1024);
    defer std.heap.page_allocator.free(content);

    return parseTheme(content);
}

fn parseTheme(content: []const u8) !Theme {
    var theme = Theme.init("parsed_theme");
    var lines = std.mem.split(u8, content, "\n");

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len == 0) continue;

        if (std.mem.startsWith(u8, trimmed, "<") and std.mem.endsWith(u8, trimmed, ">")) {
            const component = try parseComponent(trimmed[1 .. trimmed.len - 1]);
            try theme.components.append(component);
        }
    }

    return theme;
}

fn parseComponent(component_str: []const u8) !Component {
    var parts = std.mem.split(u8, component_str, " ");
    const kind_str = parts.next() orelse return error.InvalidComponent;
    const kind = std.meta.stringToEnum(ComponentKind, kind_str) orelse return error.UnknownComponentKind;

    var component = Component.init(kind);

    while (parts.next()) |part| {
        var kv = std.mem.split(u8, part, "=");
        const key = kv.next() orelse continue;
        const value = kv.next() orelse continue;
        try component.properties.put(key, value);
    }

    return component;
}

//=========================== Rendering ===========================
pub fn render(theme: Theme) !void {
    for (theme.components.items) |component| {
        try renderComponent(component);
    }
}

fn renderComponent(component: Component) !void {
    switch (component.kind) {
        .Username => try renderUsername(),
        .OS => try renderOS(),
        .Hostname => try renderHostname(),
        .Kernel => try renderKernel(),
        .Uptime => try renderUptime(),
        .Packages => try renderPackages(),
        .Shell => try renderShell(),
        .Terminal => try renderTerminal(),
        .Resolution => try renderResolution(),
        .DE => try renderDE(),
        .WM => try renderWM(),
        .Theme => try renderTheme(),
        .CPU => try renderCPU(),
        .GPU => try renderGPU(),
        .Memory => try renderMemory(),
        .TopBar => try renderTopBar(),
    }
}

fn renderUsername() !void {
    const username = try fetch.getUsername();
    std.debug.print("User: {s}\n", .{username});
}

fn renderOS() !void {
    const os = try fetch.getOS();
    std.debug.print("OS: {s}\n", .{os});
}

fn renderHostname() !void {
    const hostname = try fetch.getHostDevice();
    std.debug.print("Host: {s}\n", .{hostname});
}

fn renderKernel() !void {
    const kernel = try fetch.getKernel();
    std.debug.print("Kernel: {s}\n", .{kernel});
}

fn renderUptime() !void {
    const uptime = try fetch.getUptime();
    std.debug.print("Uptime: {s}\n", .{uptime});
}

fn renderPackages() !void {
    const packages = try fetch.getPackages();
    std.debug.print("Packages: {s}\n", .{packages});
}

fn renderShell() !void {
    const shell = try fetch.getShell();
    std.debug.print("Shell: {s}\n", .{shell});
}

fn renderTerminal() !void {
    const terminal = try fetch.getTerminal();
    std.debug.print("Terminal: {s}\n", .{terminal});
}

fn renderResolution() !void {
    const resolution = try fetch.getResolution();
    std.debug.print("Resolution: {s}\n", .{resolution});
}

fn renderDE() !void {
    const de = try fetch.getDE();
    std.debug.print("DE: {s}\n", .{de});
}

fn renderWM() !void {
    const wm = try fetch.getWM();
    std.debug.print("WM: {s}\n", .{wm});
}

fn renderTheme() !void {
    const theme = try fetch.getTheme();
    std.debug.print("Theme: {s}\n", .{theme});
}

fn renderCPU() !void {
    const cpu = try fetch.getCPU();
    std.debug.print("CPU: {s}\n", .{cpu});
}

fn renderGPU() !void {
    const gpu = try fetch.getGPU();
    std.debug.print("GPU: {s}\n", .{gpu});
}

fn renderMemory() !void {
    const memory = try fetch.getMemory();
    std.debug.print("Memory: {s}\n", .{memory});
}

fn renderTopBar() !void {
    std.debug.print("-------------------------------------\n", .{});
}
//=========================== Memory Size Formatting ==============================================

pub fn displayInfo(writer: anytype, username: []const u8, os: []const u8, cpu: []const u8, memory: []const u8, uptime: []const u8) !void {
    try writer.print("Username: {s}\n", .{username});
    try writer.print("OS: {s}\n", .{os});
    try writer.print("CPU: {s}\n", .{cpu});
    try writer.print("Memory: {s}\n", .{memory});
    try writer.print("Uptime: {s}\n", .{uptime});
}

//TODO: Refactor unit display such that memory total and used each have their own units, based on what looks cleanest.
const MemoryUnit = enum {
    None,
    KB,
    MB,
    GB,
};

fn toFixedUnit(value: []const u8, unit: MemoryUnit, precision: u32) []const u8 {
    const divisor: f64 = switch (unit) {
        .None => 1,
        .KB => 1024,
        .MB => 1024 * 1024,
        .GB => 1024 * 1024 * 1024,
    };

    const floatValue: f64 = std.fmt.parseFloat(f64, std.mem.trim(u8, value, "\n")) catch -1.0;
    var buffer: [100]u8 = undefined;
    const formatted = std.fmt.formatFloat(buffer[0..], (floatValue / divisor), .{ .precision = precision, .mode = .decimal }) catch "-1.0";
    std.debug.print("formatted: {s}\n", .{formatted});
    return formatted;
}
