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
    var buffer = try buf.Buffer.init(std.heap.page_allocator, 50, 80); // Initial size
    defer buffer.deinit();
    var logo: ?Component = undefined;

    for (theme.components.items) |component| {
        if (component.kind == .Logo) { //Defer logo last to position correctly
            logo = component;
        } else {
            try renderComponent(&buffer, component);
        }
    }

    if (logo != null) {
        try renderComponent(&buffer, logo.?);
    }

    const stdout = std.io.getStdOut().writer();
    try buffer.render(stdout);
}

fn renderComponent(buffer: *buf.Buffer, component: Component) !void {
    switch (component.kind) {
        .Username => try renderUsername(buffer),
        .OS => try renderOS(buffer),
        .Hostname => try renderHostname(buffer),
        .Kernel => try renderKernel(buffer),
        .Uptime => try renderUptime(buffer),
        .Packages => try renderPackages(buffer),
        .Shell => try renderShell(buffer),
        .Terminal => try renderTerminal(buffer),
        .Resolution => try renderResolution(buffer),
        .DE => try renderDE(buffer),
        .WM => try renderWM(buffer),
        .Theme => try renderTheme(buffer),
        .CPU => try renderCPU(buffer),
        .GPU => try renderGPU(buffer),
        .Memory => try renderMemory(buffer),
        .Logo => try renderLogo(buffer, component),
        .TopBar => try renderTopBar(buffer),
    }
}

fn renderUsername(buffer: *buf.Buffer) !void {
    const username = try fetch.getUsername();
    try buffer.write(buffer.getCurrentRow(), 0, "User: ");
    try buffer.write(buffer.getCurrentRow(), 6, username);
    try buffer.addRow();
}

fn renderOS(buffer: *buf.Buffer) !void {
    const os = try fetch.getOS();
    try buffer.write(buffer.getCurrentRow(), 0, "OS: ");
    try buffer.write(buffer.getCurrentRow(), 4, os);
    try buffer.addRow();
}

fn renderHostname(buffer: *buf.Buffer) !void {
    const hostname = try fetch.getHostDevice();
    try buffer.write(buffer.getCurrentRow(), 0, "Host: ");
    try buffer.write(buffer.getCurrentRow(), 6, hostname);
    try buffer.addRow();
}

fn renderKernel(buffer: *buf.Buffer) !void {
    const kernel = try fetch.getKernel();
    try buffer.write(buffer.getCurrentRow(), 0, "Kernel: ");
    try buffer.write(buffer.getCurrentRow(), 8, kernel);
    try buffer.addRow();
}

fn renderUptime(buffer: *buf.Buffer) !void {
    const uptime = try fetch.getUptime();
    try buffer.write(buffer.getCurrentRow(), 0, "Uptime: ");
    try buffer.write(buffer.getCurrentRow(), 8, uptime);
    try buffer.addRow();
}

fn renderPackages(buffer: *buf.Buffer) !void {
    const packages = try fetch.getPackages();
    try buffer.write(buffer.getCurrentRow(), 0, "Packages: ");
    try buffer.write(buffer.getCurrentRow(), 10, packages);
    try buffer.addRow();
}

fn renderShell(buffer: *buf.Buffer) !void {
    const shell = try fetch.getShell();
    try buffer.write(buffer.getCurrentRow(), 0, "Shell: ");
    try buffer.write(buffer.getCurrentRow(), 6, shell);
    try buffer.addRow();
}

fn renderTerminal(buffer: *buf.Buffer) !void {
    const terminal = try fetch.getTerminal();
    try buffer.write(buffer.getCurrentRow(), 0, "Terminal: ");
    try buffer.write(buffer.getCurrentRow(), 9, terminal);
    try buffer.addRow();
}

fn renderResolution(buffer: *buf.Buffer) !void {
    const resolution = try fetch.getResolution();
    try buffer.write(buffer.getCurrentRow(), 0, "Resolution: ");
    try buffer.write(buffer.getCurrentRow(), 12, resolution);
    try buffer.addRow();
}

fn renderDE(buffer: *buf.Buffer) !void {
    const de = try fetch.getDE();
    try buffer.write(buffer.getCurrentRow(), 0, "DE: ");
    try buffer.write(buffer.getCurrentRow(), 4, de);
    try buffer.addRow();
}

fn renderWM(buffer: *buf.Buffer) !void {
    const wm = try fetch.getWM();
    try buffer.write(buffer.getCurrentRow(), 0, "WM: ");
    try buffer.write(buffer.getCurrentRow(), 4, wm);
    try buffer.addRow();
}

fn renderTheme(buffer: *buf.Buffer) !void {
    const theme = try fetch.getTheme();
    try buffer.write(buffer.getCurrentRow(), 0, "Theme: ");
    try buffer.write(buffer.getCurrentRow(), 7, theme);
    try buffer.addRow();
}

fn renderCPU(buffer: *buf.Buffer) !void {
    const cpu = try fetch.getCPU();
    try buffer.write(buffer.getCurrentRow(), 0, "CPU: ");
    try buffer.write(buffer.getCurrentRow(), 5, cpu);
    try buffer.addRow();
}

fn renderGPU(buffer: *buf.Buffer) !void {
    const gpu = try fetch.getGPU();
    try buffer.write(buffer.getCurrentRow(), 0, "GPU: ");
    try buffer.write(buffer.getCurrentRow(), 5, gpu);
    try buffer.addRow();
}

fn renderMemory(buffer: *buf.Buffer) !void {
    const memory = try fetch.getMemory();
    try buffer.write(buffer.getCurrentRow(), 0, "Memory: ");
    try buffer.write(buffer.getCurrentRow(), 8, memory);
    try buffer.addRow();
}

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

fn renderLogo(buffer: *buf.Buffer, component: Component) !void {
    const position = component.properties.get("position") orelse "inline";
    const ascii_art = try fetch.getLogo();
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
            std.debug.print("Left\n", .{});
            const max_width = getMaxWidth(ascii_art);
            var row: usize = 0;
            while (ascii_lines.next()) |line| {
                if (row >= buffer.getCurrentRow()) {
                    try buffer.addRow();
                }
                try buffer.write(row, 0, line);
                row += 1;
            }
            var tempBuffer = try std.heap.page_allocator.alloc(u8, buffer.width);
            defer std.heap.page_allocator.free(tempBuffer);

            for (buffer.lines.items[0..buffer.getCurrentRow()], 0..) |line, row_thing| {
                const lineLen = line.len;
                if (lineLen <= max_width + 1) continue;
                const shiftAmount = max_width + 1;

                @memcpy(tempBuffer[0 .. lineLen - shiftAmount], line[shiftAmount..]);
                @memcpy(buffer.lines.items[row_thing][max_width + 1 ..], tempBuffer[0 .. lineLen - max_width - 1]);
                @memset(buffer.lines.items[row_thing][0 .. max_width + 1], ' ');
            }
        },
        .Right => {
            var row: usize = 0;
            const logo_width = getMaxWidth(ascii_art);
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

fn renderTopBar(buffer: *buf.Buffer) !void {
    const top_bar = "-------------------------------------";
    try buffer.write(buffer.getCurrentRow(), 0, top_bar);
    try buffer.addRow();
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
