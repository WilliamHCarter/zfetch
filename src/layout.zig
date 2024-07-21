//==================================================================================================
// File:       layout.zig
// Contents:   System for rendering fetched info based on theme file preferences.
// Author:     Will Carter
//==================================================================================================
const std = @import("std");
const fetch = @import("fetch.zig");
const buf = @import("utils/buffer.zig");
const Timer = @import("utils/timer.zig").Timer;
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
const FetchResult = struct {
    component: Component,
    result: []const u8,
};

pub fn render(theme: Theme) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("Memory leaks detected: {}\n", .{err});
    }

    var timer = try Timer.init(allocator);
    defer timer.deinit();
    timer.start();

    var results = std.ArrayList(FetchResult).init(allocator);
    defer {
        for (results.items) |item| {
            allocator.free(item.result);
        }
        results.deinit();
    }

    var buffer = try buf.Buffer.init(allocator, 50, 80);
    defer buffer.deinit();

    var mutex = std.Thread.Mutex{};
    var fetch_queue = std.ArrayList(Component).init(allocator);
    defer fetch_queue.deinit();

    try fetch_queue.appendSlice(theme.components.items);

    var threads: [6]std.Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, fetchWorker, .{
            allocator,
            &mutex,
            &fetch_queue,
            &results,
            &timer,
        });
    }

    for (threads) |thread| {
        thread.join();
    }

    std.sort.block(FetchResult, results.items, theme, componentOrder);
    var logo: ?Component = undefined;
    for (results.items) |result| {
        if (result.component.kind == ComponentKind.Logo) {
            logo = result.component;
            continue;
        }
        try renderComponent(&buffer, result.component, result.result);
    }

    if (logo != null) {
        try renderComponent(&buffer, logo.?, "");
    }
    const stdout = std.io.getStdOut().writer();
    try buffer.render(stdout);
    try timer.printResults(stdout);
}

fn fetchWorker(
    allocator: std.mem.Allocator,
    mutex: *std.Thread.Mutex,
    fetch_queue: *std.ArrayList(Component),
    results: *std.ArrayList(FetchResult),
    timer: *Timer,
) !void {
    while (true) {
        mutex.lock();
        const component = if (fetch_queue.popOrNull()) |c| c else {
            mutex.unlock();
            break;
        };
        mutex.unlock();

        const lap_key = try std.fmt.allocPrint(allocator, "fetch_{s}", .{@tagName(component.kind)});
        const start_time = try timer.startLap(lap_key);

        const result = fetchComponent(allocator, component);

        try timer.endLap(lap_key, start_time);

        mutex.lock();
        try results.append(.{ .component = component, .result = result });
        mutex.unlock();

        allocator.free(lap_key);
    }
}

fn componentOrder(theme: Theme, a: FetchResult, b: FetchResult) bool {
    for (theme.components.items) |component| {
        if (component.kind == a.component.kind) {
            return true;
        } else if (component.kind == b.component.kind) {
            return false;
        }
    }
    return false;
}

fn renderComponent(buffer: *buf.Buffer, component: Component, fetched_result: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(buffer.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    switch (component.kind) {
        .Username => try buffer.addComponentRow("", fetched_result),
        .OS => try buffer.addComponentRow("OS: ", fetched_result),
        .Hostname => try buffer.addComponentRow("Host: ", fetched_result),
        .Kernel => try buffer.addComponentRow("Kernel: ", fetched_result),
        .Uptime => try buffer.addComponentRow("Uptime: ", fetched_result),
        .Packages => try buffer.addComponentRow("Packages: ", fetched_result),
        .Shell => try buffer.addComponentRow("Shell: ", fetched_result),
        .Terminal => try buffer.addComponentRow("Terminal: ", fetched_result),
        .Resolution => try buffer.addComponentRow("Resolution: ", fetched_result),
        .DE => try buffer.addComponentRow("DE: ", fetched_result),
        .WM => try buffer.addComponentRow("WM: ", fetched_result),
        .Theme => try buffer.addComponentRow("Theme: ", fetched_result),
        .CPU => try buffer.addComponentRow("CPU: ", fetched_result),
        .GPU => try buffer.addComponentRow("GPU: ", fetched_result),
        .Memory => try renderMemory(component, buffer, allocator),
        .Logo => try renderLogo(buffer, component, allocator),
        .TopBar => try renderTopBar(buffer),
        .Colors => try renderColors(buffer, allocator),
    }
}

fn fetchComponent(allocator: std.mem.Allocator, component: Component) []const u8 {
    return switch (component.kind) {
        .Username => fetch.getUsername(allocator),
        .OS => fetch.getOS(allocator),
        .Hostname => fetch.getHostDevice(allocator),
        .Kernel => fetch.getKernel(allocator),
        .Uptime => fetch.getUptime(allocator),
        .Packages => fetch.getPackages(allocator),
        .Shell => fetch.getShell(allocator),
        .Terminal => fetch.getTerminal(allocator),
        .Resolution => fetch.getResolution(allocator),
        .DE => fetch.getDE(allocator),
        .WM => fetch.getWM(allocator),
        .Theme => fetch.getTheme(allocator),
        .CPU => fetch.getCPU(allocator),
        .GPU => fetch.getGPU(allocator),
        .Memory, .Logo, .TopBar, .Colors => allocator.dupe(u8, ""),
    } catch "Fetch Error";
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
    try buffer.addComponentRow("Memory: ", memory);
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
