//==================================================================================================
// File:       layout.zig
// Contents:   System for rendering fetched info based on theme file preferences.
// Author:     Will Carter
//==================================================================================================
const std = @import("std");
const fetch = @import("fetch.zig");
const buf = @import("buffer.zig");
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
    Logo,
    TopBar,
    Colors,
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

    const content = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, path, 1024 * 1024);
    const theme = try parseTheme(content);
    return theme;
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
    const start_time = std.time.microTimestamp();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("Memory leaks detected: {}\n", .{err});
    }
    const allocator = gpa.allocator();

    var buffer = try buf.Buffer.init(allocator, 50, 80);
    defer buffer.deinit();
    var first_component_time: i128 = 0;
    var last_component_end_time: i128 = 0;
    var timer_idx: i128 = 0;
    var logo: ?Component = undefined;
    for (theme.components.items) |component| {
        if (timer_idx == 0) {
            first_component_time = std.time.microTimestamp();
        }
        const component_start_time = std.time.microTimestamp();
        if (component.kind == .Logo) { //Defer logo last to position correctly
            logo = component;
        } else {
            try renderComponent(&buffer, component);
        }

        const component_end_time = std.time.microTimestamp();
        std.debug.print("Component {} rendered in {} ns\n", .{ timer_idx, component_end_time - component_start_time });
        last_component_end_time = component_end_time;
        timer_idx += 1;
    }

    if (logo != null) {
        const logo_start_time = std.time.microTimestamp();
        try renderComponent(&buffer, logo.?);
        const logo_end_time = std.time.microTimestamp();

        std.debug.print("Logo component rendered in {} ns\n", .{logo_end_time - logo_start_time});
        last_component_end_time = logo_end_time;
    }

    const render_end_time = std.time.microTimestamp();
    const total_render_time = render_end_time - start_time;
    const time_to_first_component = first_component_time - start_time;
    const time_after_last_component = render_end_time - last_component_end_time;

    std.debug.print("Time to first component: {} ns\n", .{time_to_first_component});
    std.debug.print("Time to render all components: {} ns\n", .{last_component_end_time - first_component_time});
    std.debug.print("Time after last component to finish: {} ns\n", .{time_after_last_component});
    std.debug.print("Total render time: {} ns\n", .{total_render_time});

    const stdout = std.io.getStdOut().writer();
    try buffer.render(stdout);
}

fn renderComponent(buffer: *buf.Buffer, component: Component) !void {
    var arena = std.heap.ArenaAllocator.init(buffer.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    switch (component.kind) {
        .Username => try renderUsername(buffer, allocator),
        .OS => try renderOS(buffer, allocator),
        .Hostname => try renderHostname(buffer, allocator),
        .Kernel => try renderKernel(buffer, allocator),
        .Uptime => try renderUptime(buffer, allocator),
        .Packages => try renderPackages(buffer, allocator),
        .Shell => try renderShell(buffer, allocator),
        .Terminal => try renderTerminal(buffer, allocator),
        .Resolution => try renderResolution(buffer, allocator),
        .DE => try renderDE(buffer, allocator),
        .WM => try renderWM(buffer, allocator),
        .Theme => try renderTheme(buffer, allocator),
        .CPU => try renderCPU(buffer, allocator),
        .GPU => try renderGPU(buffer, allocator),
        .Memory => try renderMemory(component, buffer, allocator),
        .Logo => try renderLogo(buffer, component, allocator),
        .TopBar => try renderTopBar(buffer),
        .Colors => try renderColors(buffer, allocator),
    }
}

fn renderUsername(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const username = try fetch.getUsername(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, username);
    try buffer.addRow();
}

fn renderOS(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const os = try fetch.getOS(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "OS: ");
    try buffer.write(buffer.getCurrentRow(), 4, os);
    try buffer.addRow();
}

fn renderHostname(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const hostname = try fetch.getHostDevice(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Host: ");
    try buffer.write(buffer.getCurrentRow(), 6, hostname);
    try buffer.addRow();
}

fn renderKernel(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const kernel = try fetch.getKernel(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Kernel: ");
    try buffer.write(buffer.getCurrentRow(), 8, kernel);
    try buffer.addRow();
}

fn renderUptime(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const uptime = try fetch.getUptime(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Uptime: ");
    try buffer.write(buffer.getCurrentRow(), 8, uptime);
    try buffer.addRow();
}

fn renderPackages(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const packages = try fetch.getPackages(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Packages: ");
    try buffer.write(buffer.getCurrentRow(), 10, packages);
    try buffer.addRow();
}

fn renderShell(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const shell = try fetch.getShell(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Shell: ");
    try buffer.write(buffer.getCurrentRow(), 7, shell);
    try buffer.addRow();
}

fn renderTerminal(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const terminal = try fetch.getTerminal(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Terminal: ");
    try buffer.write(buffer.getCurrentRow(), 10, terminal);
    try buffer.addRow();
}

fn renderResolution(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const resolution = try fetch.getResolution(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Resolution: ");
    try buffer.write(buffer.getCurrentRow(), 12, resolution);
    try buffer.addRow();
}

fn renderDE(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const de = try fetch.getDE(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "DE: ");
    try buffer.write(buffer.getCurrentRow(), 4, de);
    try buffer.addRow();
}

fn renderWM(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const wm = try fetch.getWM(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "WM: ");
    try buffer.write(buffer.getCurrentRow(), 4, wm);
    try buffer.addRow();
}

fn renderTheme(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const theme = try fetch.getTheme(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "Theme: ");
    try buffer.write(buffer.getCurrentRow(), 7, theme);
    try buffer.addRow();
}

fn renderCPU(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const cpu = try fetch.getCPU(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "CPU: ");
    try buffer.write(buffer.getCurrentRow(), 5, cpu);
    try buffer.addRow();
}

fn renderGPU(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const gpu = try fetch.getGPU(allocator);
    try buffer.write(buffer.getCurrentRow(), 0, "GPU: ");
    try buffer.write(buffer.getCurrentRow(), 5, gpu);
    try buffer.addRow();
}

//=========================== Memory Rendering ===========================
const MemoryUnit = enum {
    B,
    KB,
    MB,
    GB,
    Auto,
};

fn unitToStr(unit: MemoryUnit) []const u8 {
    return switch (unit) {
        .B => "B",
        .KB => "KiB",
        .MB => "MiB",
        .GB => "GiB",
        .Auto => "B",
    };
}

fn toFixedUnit(value: []const u8, unit: MemoryUnit, precision: u32, allocator: std.mem.Allocator) []const u8 {
    const divisor: f64 = switch (unit) {
        .B => 1,
        .KB => 1024,
        .MB => 1024 * 1024,
        .GB => 1024 * 1024 * 1024,
        .Auto => 1,
    };

    const floatValue: f64 = std.fmt.parseFloat(f64, std.mem.trim(u8, value, "\n")) catch -1.0;
    var buffer: []u8 = allocator.alloc(u8, 100) catch undefined;
    const formatted = std.fmt.formatFloat(buffer[0..], (floatValue / divisor), .{ .precision = precision, .mode = .decimal }) catch "-1.0";
    return formatted;
}

fn toMemoryString(mem_used: []const u8, mem_total: []const u8, unit: MemoryUnit, precision: u32, allocator: std.mem.Allocator) []const u8 {
    const used = toFixedUnit(mem_used, unit, precision, allocator);
    const total = toFixedUnit(mem_total, unit, precision, allocator);
    return std.fmt.allocPrint(allocator, "{s}{s} / {s}{s}", .{ used, unitToStr(unit), total, unitToStr(unit) }) catch "Rendering Error";
}

fn renderMemory(component: Component, buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    var memory = try fetch.getMemory(allocator);

    var it = std.mem.split(u8, memory, " / ");
    const mem_used = it.next() orelse unreachable;
    const mem_total = it.next() orelse unreachable;
    const unit = component.properties.get("unit") orelse "Auto";

    switch (std.meta.stringToEnum(MemoryUnit, unit) orelse .Auto) {
        .B => memory = toMemoryString(mem_used, mem_total, .B, 2, allocator),
        .KB => memory = toMemoryString(mem_used, mem_total, .KB, 2, allocator),
        .MB => memory = toMemoryString(mem_used, mem_total, .MB, 2, allocator),
        .GB => memory = toMemoryString(mem_used, mem_total, .GB, 2, allocator),
        .Auto => {
            const used_value = std.fmt.parseFloat(f64, std.mem.trim(u8, mem_used, "\n")) catch -1.0;
            const total_value = std.fmt.parseFloat(f64, std.mem.trim(u8, mem_total, "\n")) catch -1.0;

            const used_unit: MemoryUnit = if (used_value < 1024) .B else if (used_value < 1024 * 1024) .KB else if (used_value < 1024 * 1024 * 1024) .MB else .GB;

            const total_unit: MemoryUnit = if (total_value < 1024) .B else if (total_value < 1024 * 1024) .KB else if (total_value < 1024 * 1024 * 1024) .MB else .GB;

            const used = toFixedUnit(mem_used, used_unit, 2, allocator);
            const total = toFixedUnit(mem_total, total_unit, 2, allocator);
            memory = std.fmt.allocPrint(allocator, "{s}{s} / {s}{s}", .{ used, unitToStr(used_unit), total, unitToStr(total_unit) }) catch "Rendering Error";
        },
    }

    try buffer.write(buffer.getCurrentRow(), 0, "Memory: ");
    try buffer.write(buffer.getCurrentRow(), 8, memory);
    try buffer.addRow();
}

//=========================== Logo Rendering ===========================
const LogoPosition = enum {
    Top,
    Bottom,
    Left,
    Right,
    Inline,
};

fn getMaxWidth(ascii_art: []const u8) usize {
    var max: usize = 0;
    var lines = std.mem.split(u8, ascii_art, "\n");
    while (lines.next()) |line| {
        max = @max(max, line.len);
    }
    return max;
}

fn renderLogo(buffer: *buf.Buffer, component: Component, allocator: std.mem.Allocator) !void {
    const position = component.properties.get("position") orelse "inline";
    const ascii_art = try fetch.getLogo(allocator);
    const logo_width = getMaxWidth(ascii_art);
    var ascii_lines = std.mem.split(u8, ascii_art, "\n");
    const ascii_height = std.mem.count(u8, ascii_art, "\n") + 1;
    switch (std.meta.stringToEnum(LogoPosition, position) orelse .Inline) {
        .Top => {
            try buffer.shiftRowsDown(0, ascii_height);
            var row: usize = 0;
            while (ascii_lines.next()) |line| {
                try buffer.write(row, 0, line);
                row += 1;
            }
        },
        .Bottom => {
            const start_row = buffer.getCurrentRow();
            var row = start_row;
            while (ascii_lines.next()) |line| {
                try buffer.write(row, 0, line);
                row += 1;
                try buffer.addRow();
            }
        },
        .Left => {
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try std.heap.page_allocator.alloc(u8, logo_width + 3);
                if (row >= buffer.getCurrentRow()) {
                    try buffer.addRow();
                }
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                buffer.insertLeft(row, curr_line);
                row += 1;
            }
            while (row < buffer.getCurrentRow()) {
                var blank_width = try std.heap.page_allocator.alloc(u8, logo_width + 3);
                for (blank_width) |*c| {
                    c.* = ' ';
                }
                buffer.insertLeft(row, blank_width[0..]);
                row += 1;
            }
        },
        .Right => {
            var row: usize = 0;
            const start_column = buffer.width - logo_width;
            while (ascii_lines.next()) |line| {
                if (row >= buffer.getCurrentRow()) {
                    try buffer.addRow();
                }
                try buffer.write(row, start_column, line);
                row += 1;
            }
        },
        .Inline => {
            std.debug.print("Inline\n", .{});
            const start_row = buffer.getCurrentRow();
            var row = start_row;
            while (ascii_lines.next()) |line| {
                try buffer.write(row, 0, line);
                try buffer.addRow();
                row += 1;
            }
        },
    }
}

fn renderColors(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const colors = try fetch.getColors(allocator);
    var color_lines = std.mem.split(u8, colors, "\n");
    const first_line = color_lines.next() orelse return error.InvalidColorFile;
    const second_line = color_lines.next() orelse return error.InvalidColorFile;
    try buffer.write(buffer.getCurrentRow(), 0, first_line);
    try buffer.addRow();
    try buffer.write(buffer.getCurrentRow(), 0, second_line);
    try buffer.addRow();
}

fn renderTopBar(buffer: *buf.Buffer) !void {
    const top_bar = "-------------------------------------";
    try buffer.write(buffer.getCurrentRow(), 0, top_bar);
    try buffer.addRow();
}
