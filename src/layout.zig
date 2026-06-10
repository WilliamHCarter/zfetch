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
const Color = @import("utils/logo.zig").Color;
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

pub const ComponentKind = enum {
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

pub const Theme = struct {
    name: []const u8,
    components: std.array_list.Managed(Component),

    pub fn init(name: []const u8) Theme {
        return .{
            .name = name,
            .components = std.array_list.Managed(Component).init(std.heap.page_allocator),
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
    primary: []const u8,
    secondary: []const u8,

    pub fn init(allocator: std.mem.Allocator, primary: ?usize, secondary: ?usize, fallbacks: []usize) !Colors {
        const fallback_primary = if (fallbacks.len >= 1) fallbacks[0] else 93;
        const fallback_secondary = if (fallbacks.len >= 2) fallbacks[1] else fallback_primary;

        return Colors{
            .primary = try std.fmt.allocPrint(allocator, "\x1b[1m\x1b[{any}m", .{primary orelse fallback_primary}),
            .secondary = try std.fmt.allocPrint(allocator, "\x1b[1m\x1b[{any}m", .{secondary orelse fallback_secondary}),
        };
    }
};

pub var col: Colors = undefined;

//================================== Parsing ===================================

pub fn loadTheme(file: []const u8) !Theme {
    const theme = try parseTheme(file);
    return theme;
}

fn parseTheme(content: []const u8) !Theme {
    var theme = Theme.init("parsed_theme");
    var lines = std.mem.splitSequence(u8, content, newline);

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

pub fn parseComponent(component_str: []const u8) !Component {
    var parts = std.mem.splitSequence(u8, component_str, " ");
    const kind_str = parts.next() orelse return error.InvalidComponent;
    const kind = std.meta.stringToEnum(ComponentKind, kind_str) orelse return error.UnknownComponentKind;

    var component = Component.init(kind);

    while (parts.next()) |part| {
        var kv = std.mem.splitSequence(u8, part, "=");
        const key = kv.next() orelse continue;
        const value = kv.next() orelse continue;
        try component.properties.put(key, value);
    }
    return component;
}
//================================== Fetching ==================================
fn fetchHandler(theme: Theme, allocator: std.mem.Allocator, timer: *Timer) !std.array_list.Managed(FetchResult) {
    var mutex: std.atomic.Mutex = .unlocked;
    var fetch_queue = try std.array_list.Managed(Component).initCapacity(allocator, theme.components.items.len);
    defer fetch_queue.deinit();

    try fetch_queue.appendSlice(theme.components.items);

    var results = try std.array_list.Managed(FetchResult).initCapacity(allocator, theme.components.items.len);

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
    mutex: *std.atomic.Mutex,
    fetch_queue: *std.array_list.Managed(Component),
    fetch_results: *std.array_list.Managed(FetchResult),
    timer: *Timer,
) !void {
    while (true) {
        lock(mutex);
        const component = if (fetch_queue.pop()) |c| c else {
            mutex.unlock();
            break;
        };
        mutex.unlock();

        var lap_key_buffer: [32]u8 = undefined;
        const lap_key = try std.fmt.bufPrint(&lap_key_buffer, "fetch_{s}", .{@tagName(component.kind)});
        const start_time = try timer.startLap(lap_key);

        const outcome = fetchComponent(allocator, component);

        try timer.endLap(lap_key, start_time);

        lock(mutex);
        try fetch_results.append(.{ .component = component, .outcome = outcome });
        mutex.unlock();
    }
}

fn lock(mutex: *std.atomic.Mutex) void {
    while (!mutex.tryLock()) {
        std.atomic.spinLoopHint();
    }
}

fn getDistroColors(allocator: std.mem.Allocator, theme: Theme) !Colors {
    var image: []const u8 = "";

    for (theme.components.items) |component| {
        if (component.kind == ComponentKind.Logo) {
            image = component.properties.get("image") orelse "";
        }
    }
    const logo = try fetch.getLogo(allocator, image);

    var primary: ?usize = null;
    var secondary: ?usize = null;

    if (logo.color_primary) |color| {
        primary = @intFromEnum(color);
    }
    if (logo.color_secondary) |color| {
        secondary = @intFromEnum(color);
    }

    const colors = try allocator.alloc(usize, logo.colors.len);
    for (logo.colors, 0..) |color, i| {
        colors[i] = @intFromEnum(color);
    }

    return try Colors.init(allocator, primary, secondary, colors);
}

//================================ Rendering ===================================
const FetchOutcome = union(enum) {
    success: []const u8,
    failure: anyerror,

    fn text(self: FetchOutcome) []const u8 {
        return switch (self) {
            .success => |value| value,
            .failure => "Fetch Error",
        };
    }
};

const FetchResult = struct {
    component: Component,
    outcome: FetchOutcome,
};

pub fn render(theme: Theme, allocator: std.mem.Allocator) !void {
    var timer = try Timer.init(allocator);
    defer timer.deinit();
    timer.start();

    var arn = std.heap.ArenaAllocator.init(allocator);
    defer arn.deinit();
    const arena = arn.allocator();
    col = try getDistroColors(arena, theme);

    var fetch_results = try fetchHandler(theme, allocator, &timer);
    defer {
        for (fetch_results.items) |item| {
            switch (item.outcome) {
                .success => |value| allocator.free(value),
                .failure => {},
            }
        }
        fetch_results.deinit();
    }

    const start_time = try timer.startLap("render");
    var buffer = try buf.Buffer.init(allocator, 512);
    defer buffer.deinit();
    std.sort.insertion(FetchResult, fetch_results.items, theme, componentOrder);

    var logo_index: ?usize = null;
    for (fetch_results.items, 0..) |result, idx| {
        if (result.component.kind == ComponentKind.Logo) {
            logo_index = idx;
            break;
        }
    }

    if (logo_index) |idx| {
        const logo = fetch_results.orderedRemove(idx);
        const position = logo.component.properties.get("position") orelse "inline";

        switch (std.meta.stringToEnum(LogoPosition, position) orelse .Inline) {
            .Top, .Left => try fetch_results.insert(0, logo),
            .Bottom, .Right => try fetch_results.append(logo),
            .Inline => try fetch_results.insert(idx, logo),
        }
    }

    for (fetch_results.items) |result| {
        try renderComponent(&buffer, result.component, result.outcome.text());
    }

    const io = std.Io.Threaded.global_single_threaded.io();
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    try buffer.render(&stdout_writer.interface);
    try stdout_writer.interface.flush();
    try timer.endLap("render", start_time);

    if (std.c.getenv("ZFETCH_BENCH") != null) {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
        try timer.printResults(&stderr_writer.interface);
        try stderr_writer.interface.flush();
    }
}

fn componentRank(theme: Theme, kind: ComponentKind) usize {
    for (theme.components.items, 0..) |component, index| {
        if (component.kind == kind) return index;
    }
    return theme.components.items.len;
}

fn componentOrder(theme: Theme, a: FetchResult, b: FetchResult) bool {
    return componentRank(theme, a.component.kind) < componentRank(theme, b.component.kind);
}

fn renderComponent(buffer: *buf.Buffer, component: Component, fetched_result: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(buffer.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    switch (component.kind) {
        .Username => try buffer.addComponentRow(col.secondary, fetched_result, " "),
        .OS => try buffer.addComponentRow(col.primary, "OS", fetched_result),
        .Hostname => try buffer.addComponentRow(col.primary, "Host", fetched_result),
        .Kernel => try buffer.addComponentRow(col.primary, "Kernel", fetched_result),
        .Uptime => try buffer.addComponentRow(col.primary, "Uptime", fetched_result),
        .Packages => try buffer.addComponentRow(col.primary, "Packages", fetched_result),
        .Shell => try buffer.addComponentRow(col.primary, "Shell", fetched_result),
        .Terminal => try buffer.addComponentRow(col.primary, "Terminal", fetched_result),
        .Resolution => try buffer.addComponentMultiRow(col.primary, "Resolution", fetched_result),
        .DE => try buffer.addComponentRow(col.primary, "DE", fetched_result),
        .WM => try buffer.addComponentRow(col.primary, "WM", fetched_result),
        .Theme => try buffer.addComponentRow(col.primary, "Theme", fetched_result),
        .CPU => try buffer.addComponentRow(col.primary, "CPU", fetched_result),
        .GPU => try buffer.addComponentRow(col.primary, "GPU", fetched_result),
        .Memory => try buffer.addComponentRow(col.primary, "Memory", renderMemory(component, allocator)),
        .Logo => try renderLogo(component, buffer, allocator),
        .TopBar => try renderTopBar(allocator, buffer),
        .Colors => try renderColors(buffer, allocator),
    }
}

fn fetchComponent(allocator: std.mem.Allocator, component: Component) FetchOutcome {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const fetched_component: anyerror![]const u8 = switch (component.kind) {
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
    };

    const value = fetched_component catch |err| return .{ .failure = err };
    const owned = allocator.dupe(u8, value) catch |err| return .{ .failure = err };
    return .{ .success = owned };
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
    return switch (precision) {
        0 => std.fmt.allocPrint(allocator, "{d:.0}", .{floatValue / divisor}) catch "-1.0",
        1 => std.fmt.allocPrint(allocator, "{d:.1}", .{floatValue / divisor}) catch "-1.0",
        2 => std.fmt.allocPrint(allocator, "{d:.2}", .{floatValue / divisor}) catch "-1.0",
        3 => std.fmt.allocPrint(allocator, "{d:.3}", .{floatValue / divisor}) catch "-1.0",
        else => std.fmt.allocPrint(allocator, "{d}", .{floatValue / divisor}) catch "-1.0",
    };
}

fn toMemoryString(mem_used: []const u8, mem_total: []const u8, unit: MemoryUnit, precision: u32, allocator: std.mem.Allocator) []const u8 {
    const used = toFixedUnit(mem_used, unit, precision, allocator);
    const total = toFixedUnit(mem_total, unit, precision, allocator);
    return std.fmt.allocPrint(allocator, "{s}{s} / {s}{s}", .{ used, unitToStr(unit), total, unitToStr(unit) }) catch "Rendering Error";
}

fn renderMemory(component: Component, allocator: std.mem.Allocator) []const u8 {
    var memory = fetch.getMemory(allocator) catch return "Fetch Error";

    var it = std.mem.splitSequence(u8, memory, " / ");
    const mem_used = it.next() orelse return memory;
    const mem_total = it.next() orelse return memory;
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
    var color_lines = std.mem.splitSequence(u8, colors, "\n");
    const first_line = color_lines.next() orelse return error.InvalidColorFile;
    const second_line = color_lines.next() orelse return error.InvalidColorFile;
    const third_line = color_lines.next() orelse return error.InvalidColorFile;
    try buffer.append(first_line);
    try buffer.append(second_line);
    try buffer.append(third_line);
}

//❯
fn renderTopBar(allocator: std.mem.Allocator, buffer: *buf.Buffer) !void {
    const username = std.mem.trimEnd(u8, try fetch.getUsername(allocator), " ");
    const top_bar = try allocator.alloc(u8, username.len);

    const bar_symbol = "-";
    @memset(top_bar, bar_symbol[0]);

    try buffer.append(try std.mem.concat(allocator, u8, &[_][]const u8{ "\x1b[0m", top_bar }));
}

//============================== Logo Rendering ================================
const LogoPosition = enum {
    Top,
    Bottom,
    Left,
    Right,
    Inline,
};

fn visibleWidth(line: []const u8) usize {
    var width: usize = 0;
    var i: usize = 0;
    while (i < line.len) {
        if (line[i] == '\x1b') {
            while (i < line.len and line[i] != 'm') : (i += 1) {}
            if (i < line.len) i += 1;
        } else if (line[i] == '$' and i + 4 < line.len and line[i + 1] == '{' and line[i + 2] == 'c' and std.ascii.isDigit(line[i + 3]) and line[i + 4] == '}') {
            i += 5;
        } else if (line[i] == '$' and i + 1 < line.len and std.ascii.isDigit(line[i + 1])) {
            i += 2;
        } else {
            width += 1;
            i += 1;
        }
    }
    return width;
}

fn getLineWidths(ascii_art: []const u8, allocator: std.mem.Allocator, comptime visible: bool) ![]usize {
    var widths = std.array_list.Managed(usize).init(allocator);
    errdefer widths.deinit();

    var lines = std.mem.splitSequence(u8, ascii_art, "\n");
    while (lines.next()) |line| {
        try widths.append(if (visible) visibleWidth(line) else line.len);
    }

    return widths.toOwnedSlice();
}

fn getMaxWidth(ascii_art: []const u8, allocator: std.mem.Allocator) usize {
    const lines = getLineWidths(ascii_art, allocator, true) catch return 0;
    var max: usize = 0;
    for (lines) |value| {
        max = @max(max, value);
    }
    return max;
}

fn intToANSI(allocator: std.mem.Allocator, index: usize, scheme: []const usize) ![]const u8 {
    if (index == 0 or index > scheme.len) return error.IndexOutOfBounds;
    const num = scheme[index - 1];
    return try std.fmt.allocPrint(allocator, "\x1b[{d};1m", .{num});
}

fn colorize(allocator: std.mem.Allocator, ascii_art: []const u8, color_scheme: []usize) ![]u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    errdefer result.deinit();
    var color_found: bool = false;
    var current_color: ?usize = null;
    var i: usize = 0;

    while (i < ascii_art.len) {
        if (ascii_art[i] == '$' and i + 4 < ascii_art.len and ascii_art[i + 1] == '{' and ascii_art[i + 2] == 'c' and std.ascii.isDigit(ascii_art[i + 3]) and ascii_art[i + 4] == '}') {
            const color_index = ascii_art[i + 3] - '0';
            if (color_index < 16) {
                color_found = true;
                try result.appendSlice(try intToANSI(allocator, color_index, color_scheme));
                current_color = color_index;
                i += 5;
                continue;
            }
        }

        if (ascii_art[i] == '$' and i + 1 < ascii_art.len and std.ascii.isDigit(ascii_art[i + 1])) {
            const color_index = ascii_art[i + 1] - '0';
            if (color_index < 16) {
                color_found = true;
                try result.appendSlice(try intToANSI(allocator, color_index, color_scheme));
                current_color = color_index;
                i += 2;
                continue;
            }
        }
        if (ascii_art[i] == '\n') {
            try result.append('\n');
            if (current_color) |color| {
                try result.appendSlice(try intToANSI(allocator, color, color_scheme));
            }
            i += 1;
            continue;
        }
        try result.append(ascii_art[i]);
        i += 1;
    }

    if (!color_found) {
        try result.insertSlice(0, try intToANSI(allocator, 1, color_scheme));
    }

    try result.appendSlice("\x1b[0m");
    return result.toOwnedSlice();
}

fn renderLogo(logo: Component, buffer: *buf.Buffer, allocator: std.mem.Allocator) !void {
    const logo_info = try fetch.getLogo(allocator, logo.properties.get("image") orelse "");
    const ascii_art = logo_info.ascii orelse return error.AsciiFetchFailed;
    const color_scheme = try logo_info.colorsAsNums(allocator);
    const ascii_art_color = colorize(allocator, ascii_art, color_scheme) catch ascii_art;
    const logo_width = getMaxWidth(ascii_art, allocator);
    const line_widths = try getLineWidths(ascii_art_color, allocator, false);
    const visual_line_widths = try getLineWidths(ascii_art, allocator, true);
    var ascii_lines = std.mem.splitSequence(u8, ascii_art_color, newline);
    const padding = 3;
    const position = logo.properties.get("position") orelse "Inline";

    switch (std.meta.stringToEnum(LogoPosition, position) orelse .Inline) {
        .Top, .Bottom, .Inline => {
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try allocator.alloc(u8, logo_width + ((line_widths[row] - visual_line_widths[row])) + padding);
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                try buffer.insert(curr_line);
                row += 1;
            }
        },
        .Left => {
            buffer.logo_width = logo_width + padding;
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                var curr_line = try allocator.alloc(u8, logo_width + ((line_widths[row] - visual_line_widths[row])) + padding);
                @memset(curr_line, ' ');
                @memcpy(curr_line[0..line_itr.len], line_itr);
                buffer.segment_offsets.items[buffer.current_row] = @max(buffer.segment_offsets.items[buffer.current_row], curr_line.len);
                try buffer.insert(curr_line);
                row += 1;
            }
            while (row < buffer.getCurrentRow()) {
                var blank_width = try allocator.alloc(u8, logo_width + padding);
                for (blank_width) |*c| {
                    c.* = ' ';
                }
                buffer.segment_offsets.items[buffer.current_row] = @max(buffer.segment_offsets.items[buffer.current_row], logo_width);
                try buffer.insert(blank_width[0..]);
                row += 1;
            }
            buffer.current_row = 0;
        },
        .Right => {
            var row_max: usize = 0;
            for (buffer.lines.items) |item| {
                const visual_line = std.mem.trimEnd(u8, try allocator.dupe(u8, item), " ");
                row_max = @max(row_max, buffer.stripTerminalCodes(visual_line));
            }
            buffer.current_row = 0;
            var row: usize = 0;
            while (ascii_lines.next()) |line_itr| {
                const visual_line = std.mem.trimEnd(u8, try allocator.dupe(u8, buffer.lines.items[row]), " ");
                const stripped_line = buffer.stripTerminalCodes(visual_line);
                try buffer.write(row, row_max + (visual_line.len - stripped_line) + padding, line_itr);
                if (row >= buffer.getCurrentRow()) {
                    try buffer.addRow();
                }
                row += 1;
            }
        },
    }
}

//================================== Tests =====================================
test "parseComponent parses kind and key/value properties" {
    var component = try parseComponent("Logo image=linux position=Left");
    defer component.deinit();

    try std.testing.expectEqual(ComponentKind.Logo, component.kind);
    try std.testing.expectEqualStrings("linux", component.properties.get("image").?);
    try std.testing.expectEqualStrings("Left", component.properties.get("position").?);
}

test "parseComponent rejects unknown component kinds" {
    try std.testing.expectError(error.UnknownComponentKind, parseComponent("NotAComponent"));
}

test "componentOrder follows theme order and is a strict weak ordering" {
    const newline_str = newline;
    const allocator = std.testing.allocator;
    const content = try std.mem.concat(allocator, u8, &.{
        "<OS>",  newline_str,
        "<CPU>", newline_str,
    });
    defer allocator.free(content);

    var theme = try loadTheme(content);
    defer theme.deinit();

    const os_result = FetchResult{ .component = .{ .kind = .OS, .properties = undefined }, .outcome = .{ .success = "" } };
    const cpu_result = FetchResult{ .component = .{ .kind = .CPU, .properties = undefined }, .outcome = .{ .success = "" } };

    try std.testing.expect(componentOrder(theme, os_result, cpu_result));
    try std.testing.expect(!componentOrder(theme, cpu_result, os_result));
    // lessThan(a, a) must be false for a valid strict weak ordering.
    try std.testing.expect(!componentOrder(theme, os_result, os_result));
}

test "loadTheme parses component order" {
    const allocator = std.testing.allocator;
    const content = try std.mem.concat(allocator, u8, &.{
        "<Username>",                       newline,
        "<TopBar>",                         newline,
        "<OS>",                             newline,
        "<Logo image=linux position=Left>", newline,
    });
    defer allocator.free(content);

    var theme = try loadTheme(content);
    defer theme.deinit();

    try std.testing.expectEqual(@as(usize, 4), theme.components.items.len);
    try std.testing.expectEqual(ComponentKind.Username, theme.components.items[0].kind);
    try std.testing.expectEqual(ComponentKind.TopBar, theme.components.items[1].kind);
    try std.testing.expectEqual(ComponentKind.OS, theme.components.items[2].kind);
    try std.testing.expectEqual(ComponentKind.Logo, theme.components.items[3].kind);
    try std.testing.expectEqualStrings("linux", theme.components.items[3].properties.get("image").?);
}
