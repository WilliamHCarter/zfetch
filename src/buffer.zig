//==================================================================================================
// File:       buffer.zig
// Contents:   Simple buffer implementation for rendering the layout
// Author:     Will Carter
//==================================================================================================
const std = @import("std");

pub const Buffer = struct {
    lines: std.ArrayList([]u8),
    allocator: std.mem.Allocator,
    width: usize,
    row_count: usize,

    pub fn init(allocator: std.mem.Allocator, initial_height: usize, initial_width: usize) !Buffer {
        var lines = std.ArrayList([]u8).init(allocator);
        try lines.ensureTotalCapacity(initial_height);
        for (0..initial_height) |_| {
            const line = try allocator.alloc(u8, initial_width);
            @memset(line, ' ');
            try lines.append(line);
        }
        return Buffer{
            .lines = lines,
            .allocator = allocator,
            .width = initial_width,
            .row_count = 0,
        };
    }

    pub fn deinit(self: *Buffer) void {
        for (self.lines.items) |line| {
            self.allocator.free(line);
        }
        self.lines.deinit();
    }

    pub fn write(self: *Buffer, row: usize, col: usize, text: []const u8) !void {
        while (row >= self.lines.items.len) {
            const new_line = try self.allocator.alloc(u8, self.width);
            @memset(new_line, ' ');
            try self.lines.append(new_line);
        }
        const line = self.lines.items[row];
        const end = @min(col + text.len, line.len);
        @memcpy(line[col..end], text[0 .. end - col]);
    }

    pub fn getCurrentRow(self: *const Buffer) usize {
        return self.row_count;
    }

    pub fn addRow(self: *Buffer) !void {
        const new_line = try self.allocator.alloc(u8, self.width);
        @memset(new_line, ' ');
        try self.lines.append(new_line);
        self.row_count += 1;
    }

    pub fn render(self: *const Buffer, writer: anytype) !void {
        for (self.lines.items[0..self.row_count]) |line| {
            try writer.print("{s}\n", .{line});
        }
    }

    pub fn insertRowAt(self: *Buffer, at: usize) !void {
        if (at > self.row_count) return error.InvalidRowIndex;
        const new_line = try self.allocator.alloc(u8, self.width);
        @memset(new_line, ' ');
        try self.lines.insert(at, new_line);
        self.row_count += 1;
    }

    pub fn shiftRowsDown(self: *Buffer, from: usize, count: usize) !void {
        const to = from + count;
        try self.lines.ensureTotalCapacity(self.row_count + count);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            try self.addRow();
        }
        var j: usize = self.row_count - 1;
        while (j >= to) : (j -= 1) {
            if (j < from) break;
            self.lines.items[j] = self.lines.items[j - count];
        }
        for (from..to) |k| {
            const new_line = try self.allocator.alloc(u8, self.width);
            @memset(new_line, ' ');
            self.lines.items[k] = new_line;
        }
    }
};
