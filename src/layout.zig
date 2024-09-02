//==================================================================================================
// File:       layout.zig
// Contents:   System for rendering fetched info based on theme file preferences.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");
const builtin = @import("builtin");
const fetch = @import("fetch.zig");
const buf = @import("utils/buffer.zig");
const Timer = @import("utils/timer.zig").Timer;

//============================== Data Structures ===============================
const newline = switch (builtin.os.tag) {
    .windows => "\r\n",
    else => "\n",
};

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

const Colors = struct {
    const Primary = "\x1b[1m\x1b[93m";
    const Secondary = "\x1b[1m\x1b[92m";
};

const ColorMap = struct {
    codes: [16][]const u8,

    fn init() ColorMap {
        return .{
            .codes = .{
                "\x1b[30m", // Black
                "\x1b[31m", // Red
                "\x1b[32m", // Green
                "\x1b[33m", // Yellow
                "\x1b[34m", // Blue
                "\x1b[35m", // Magenta
                "\x1b[36m", // Cyan
                "\x1b[37m", // White
                "\x1b[90m", // Bright Black
                "\x1b[91m", // Bright Red
                "\x1b[92m", // Bright Green
                "\x1b[93m", // Bright Yellow
                "\x1b[94m", // Bright Blue
                "\x1b[95m", // Bright Magenta
                "\x1b[96m", // Bright Cyan
                "\x1b[97m", // Bright White
            },
        };
    }
};
//================================== Parsing ===================================

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
    var lines = std.mem.split(u8, content, newline);

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
//================================== Fetching ==================================
fn fetchHandler(theme: Theme, allocator: std.mem.Allocator, timer: *Timer) !std.ArrayList(FetchResult) {
    var mutex = std.Thread.Mutex{};
    var fetch_queue = std.ArrayList(Component).init(allocator);
    defer fetch_queue.deinit();

    try fetch_queue.appendSlice(theme.components.items);

    var results = std.ArrayList(FetchResult).init(allocator);

    var threads: [6]std.Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, fetchWorker, .{
            allocator,
            &mutex,
            &fetch_queue,
            &results,
            timer,
        });
    }

    for (threads) |thread| {
        thread.join();
    }
    return results;
}

fn fetchWorker(
    allocator: std.mem.Allocator,
    mutex: *std.Thread.Mutex,
    fetch_queue: *std.ArrayList(Component),
    fetch_results: *std.ArrayList(FetchResult),
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
        try fetch_results.append(.{ .component = component, .result = result });
        mutex.unlock();

        allocator.free(lap_key);
    }
}

//================================ Rendering ===================================
const FetchResult = struct {
    component: Component,
    result: []const u8,
};

pub fn render(theme: Theme, allocator: std.mem.Allocator) !void {
    var timer = try Timer.init(allocator);
    defer timer.deinit();
    timer.start();

    const fetch_results = try fetchHandler(theme, allocator, &timer);
    defer {
        for (fetch_results.items) |item| {
            allocator.free(item.result);
        }
        fetch_results.deinit();
    }

    const start_time = try timer.startLap("render");
    var buffer = try buf.Buffer.init(allocator, 150);
    defer buffer.deinit();
    std.sort.block(FetchResult, fetch_results.items, theme, componentOrder);
    var logo: ?Component = undefined;
    for (fetch_results.items) |result| {
        if (result.component.kind == ComponentKind.Logo) {
            logo = result.component;
            break;
        }
    }

    var is_delayed = false;
    var is_inline = false;
    const position = logo.?.properties.get("position") orelse "inline";
    switch (std.meta.stringToEnum(LogoPosition, position) orelse .Inline) {
        .Top, .Left => {
            try renderComponent(&buffer, logo.?, "");
        },
        .Bottom, .Right => {
            is_delayed = true;
        },
        .Inline => {
            is_inline = true;
        },
    }
    for (fetch_results.items) |result| {
        if ((result.component.kind == ComponentKind.Logo) and !is_inline) {
            continue;
        }
        try renderComponent(&buffer, result.component, result.result);
    }
    if (is_delayed) {
        try renderComponent(&buffer, logo.?, "result");
    }
    const stdout = std.io.getStdOut().writer();
    try buffer.render(stdout);
    try timer.endLap("render", start_time);
    try timer.printResults(stdout);
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
        .Username => try buffer.addComponentRow(Colors.Secondary, fetched_result, " "),
        .OS => try buffer.addComponentRow(Colors.Primary, "OS", fetched_result),
        .Hostname => try buffer.addComponentRow(Colors.Primary, "Host", fetched_result),
        .Kernel => try buffer.addComponentRow(Colors.Primary, "Kernel", fetched_result),
        .Uptime => try buffer.addComponentRow(Colors.Primary, "Uptime", fetched_result),
        .Packages => try buffer.addComponentRow(Colors.Primary, "Packages", fetched_result),
        .Shell => try buffer.addComponentRow(Colors.Primary, "Shell", fetched_result),
        .Terminal => try buffer.addComponentRow(Colors.Primary, "Terminal", fetched_result),
        .Resolution => try buffer.addComponentRow(Colors.Primary, "Resolution", fetched_result),
        .DE => try buffer.addComponentRow(Colors.Primary, "DE", fetched_result),
        .WM => try buffer.addComponentRow(Colors.Primary, "WM", fetched_result),
        .Theme => try buffer.addComponentRow(Colors.Primary, "Theme", fetched_result),
        .CPU => try buffer.addComponentRow(Colors.Primary, "CPU", fetched_result),
        .GPU => try buffer.addComponentRow(Colors.Primary, "GPU", fetched_result),
        .Memory => try buffer.addComponentRow(Colors.Primary, "Memory", renderMemory(component, allocator)),
        .Logo => try renderLogo(component.properties.get("position") orelse "inline", buffer, allocator),
        .TopBar => try renderTopBar(allocator, buffer),
        .Colors => try renderColors(buffer, allocator),
    }
}

fn fetchComponent(allocator: std.mem.Allocator, component: Component) []const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const fetched_component: []const u8 = switch (component.kind) {
        .Username => fetch.getUsername(arena_alloc),
        .OS => fetch.getOS(arena_alloc),
        .Hostname => fetch.getHostDevice(arena_alloc),
        .Kernel => fetch.getKernel(arena_alloc),
        .Uptime => fetch.getUptime(arena_alloc),
        .Packages => fetch.getPackages(arena_alloc),
        .Shell => fetch.getShell(arena_alloc),
        .Terminal => fetch.getTerminal(arena_alloc),
        .Resolution => fetch.getResolution(arena_alloc),
        .DE => fetch.getDE(arena_alloc),
        .WM => fetch.getWM(arena_alloc),
        .Theme => fetch.getTheme(arena_alloc),
        .CPU => fetch.getCPU(arena_alloc),
        .GPU => fetch.getGPU(arena_alloc),
        .Memory, .Logo, .TopBar, .Colors => "",
    } catch "Fetch Error";

    return allocator.dupe(u8, fetched_component) catch "Fetch Error";
}

//============================= Memory Rendering ===============================

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

fn renderMemory(component: Component, allocator: std.mem.Allocator) []const u8 {
    var memory = fetch.getMemory(allocator) catch "Fetch Error";
    if (std.mem.eql(u8, memory, "Windows")) { //Temp hack, remove later
        return memory;
    }

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
    return memory;
}

fn renderColors(buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const colors = try fetch.getColors(allocator);
    var color_lines = std.mem.split(u8, colors, "\n");
    const first_line = color_lines.next() orelse return error.InvalidColorFile;
    const second_line = color_lines.next() orelse return error.InvalidColorFile;
    const third_line = color_lines.next() orelse return error.InvalidColorFile;
    try buffer.append(first_line);
    try buffer.append(second_line);
    try buffer.append(third_line);
}

//❯
fn renderTopBar(allocator: std.mem.Allocator, buffer: *buf.Buffer) !void {
    const username = std.mem.trimRight(u8, try fetch.getUsername(allocator), " ");
    defer allocator.free(username);
    const top_bar = try allocator.alloc(u8, username.len);
    defer allocator.free(top_bar);

    const bar_symbol = "-";
    @memset(top_bar, bar_symbol[0]);

    try buffer.append(top_bar);
}
//============================== Logo Rendering ================================
const LogoPosition = enum {
    Top,
    Bottom,
    Left,
    Right,
    Inline,
};

fn processLine(line: []const u8, allocator: std.mem.Allocator, color_map: ColorMap) ![]const u8 {
    var result = try allocator.dupe(u8, line);
    errdefer allocator.free(result);

    for (color_map.codes, 0..) |color_code, i| {
        const single_digit = try std.fmt.allocPrint(allocator, "${d}", .{i});
        defer allocator.free(single_digit);
        result = try std.mem.replaceOwned(u8, allocator, result, single_digit, color_code);

        const curly_brace = try std.fmt.allocPrint(allocator, "${{c{d}}}", .{i});
        defer allocator.free(curly_brace);
        result = try std.mem.replaceOwned(u8, allocator, result, curly_brace, color_code);
    }

    return result;
}

fn getLineWidths(ascii_art: []const u8, allocator: std.mem.Allocator) ![]usize {
    var widths = std.ArrayList(usize).init(allocator);
    errdefer widths.deinit();

    var lines = std.mem.split(u8, ascii_art, "\n");
    while (lines.next()) |line| {
        const result = processLine(line, allocator, undefined) catch line;
        const visual_length: usize = result.len;
        try widths.append(visual_length);
    }

    return widths.toOwnedSlice();
}

fn getMaxWidth(ascii_art: []const u8, allocator: std.mem.Allocator) usize {
    const lines = getLineWidths(ascii_art, allocator) catch return 0;
    var max = lines[0];
    for (lines) |value| {
        max = @max(max, value);
    }
    return max;
}

fn colorize(allocator: std.mem.Allocator, ascii_art: []const u8, color_map: ColorMap) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var current_color: ?usize = null;
    var i: usize = 0;

    while (i < ascii_art.len) {
        if (ascii_art[i] == '\n') {
            try result.append('\n');
            if (current_color) |color| {
                try result.appendSlice(color_map.codes[color]);
            }
            i += 1;
            continue;
        }

        if (ascii_art[i] == '$' and i + 1 < ascii_art.len) {
            var new_color: ?usize = null;
            var skip: usize = 0;

            if (ascii_art[i + 1] == '{' and i + 4 < ascii_art.len and ascii_art[i + 4] == '}') {
                // Handle ${c3} format
                const color_index = ascii_art[i + 3] - '0';
                if (color_index >= 0 and color_index < 16) {
                    new_color = color_index;
                    skip = 5;
                }
            } else if (ascii_art[i + 1] >= '0' and ascii_art[i + 1] <= '9') {
                // Handle $3 format
                const color_index = ascii_art[i + 1] - '0';
                if (color_index >= 0 and color_index < 16) {
                    new_color = color_index;
                    skip = 2;
                }
            }

            if (new_color) |color| {
                try result.appendSlice(color_map.codes[color]);
                current_color = color;
                i += skip;
                continue;
            }
        }

        try result.append(ascii_art[i]);
        i += 1;
    }

    try result.appendSlice("\x1b[0m"); // Reset color at the end
    return result.toOwnedSlice();
}

fn renderLogo(position: []const u8, buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const ascii_art = try fetch.getLogo(allocator);
    const color_map = ColorMap.init();
    const ascii_art_color = try colorize(allocator, ascii_art, color_map);
    defer allocator.free(ascii_art_color);

    const logo_width = getMaxWidth(ascii_art, allocator);
    const line_widths = try getLineWidths(ascii_art_color, allocator);
    const visual_line_widths = try getLineWidths(ascii_art, allocator);
    var ascii_lines = std.mem.split(u8, ascii_art_color, newline);
    switch (std.meta.stringToEnum(LogoPosition, position) orelse .Inline) {
        .Top => {
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try allocator.alloc(u8, logo_width + ((line_widths[row] - visual_line_widths[row])) + 3);
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                buffer.insert(curr_line) catch {};
                row += 1;
            }
        },
        .Bottom => {
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try allocator.alloc(u8, logo_width + ((line_widths[row] - visual_line_widths[row])) + 3);
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                buffer.insert(curr_line) catch {};
                row += 1;
            }
        },
        .Left => {
            buffer.logo_width = logo_width + 3;
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try allocator.alloc(u8, logo_width + ((line_widths[row] - visual_line_widths[row])) + 3);
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                buffer.segment_offsets.items[buffer.current_row] = @max(buffer.segment_offsets.items[buffer.current_row], curr_line.len);
                buffer.insert(curr_line) catch {};
                row += 1;
            }
            while (row < buffer.getCurrentRow()) {
                var blank_width = try allocator.alloc(u8, logo_width + 3);
                for (blank_width) |*c| {
                    c.* = ' ';
                }
                buffer.segment_offsets.items[buffer.current_row] = @max(buffer.segment_offsets.items[buffer.current_row], logo_width);
                buffer.insert(blank_width[0..]) catch {};
                row += 1;
            }
            buffer.current_row = 0;
        },
        .Right => {
            // std.debug.print("seg offsets: {d}\n", .{buffer.segment_offsets.items});
            var seg_max: usize = 0;
            for (buffer.segment_offsets.items) |item| {
                seg_max = @max(seg_max, item);
            }
            // std.debug.print("seg max: {d}\n", .{seg_max});
            buffer.current_row = 0;
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                try buffer.write(row, seg_max, line_itr);
                row += 1;
            }
            while (row < buffer.getCurrentRow()) {
                var blank_width = try allocator.alloc(u8, logo_width + 3);
                for (blank_width) |*c| {
                    c.* = ' ';
                }
                buffer.segment_offsets.items[buffer.current_row] = @max(buffer.segment_offsets.items[buffer.current_row], logo_width);
                buffer.insert(blank_width[0..]) catch {};
                row += 1;
            }
        },
        .Inline => {
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try allocator.alloc(u8, logo_width + ((line_widths[row] - visual_line_widths[row])) + 3);
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                buffer.insert(curr_line) catch {};
                row += 1;
            }
        },
    }
}
