//==================================================================================================
// File:       buffer.zig
// Contents:   Buffer represents a 2D text buffer with dynamic rows and fixed-width columns.
//             Used in ZFetch for rendering the final layout to the terminal.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");
const testing = std.testing;

pub const BufferError = error{
    RowOutOfBounds,
    ColumnOutOfBounds,
};

pub const Buffer = struct {
    lines: std.ArrayList([]u8),
    allocator: std.mem.Allocator,
    width: usize,
    row_count: usize = 0,
    current_row: usize = 0,

    segment_offsets: std.ArrayList(usize),
    logo_width: usize = 0,

    pub fn init(allocator: std.mem.Allocator, initial_width: usize) !Buffer {
        var lines = std.ArrayList([]u8).init(allocator);
        for (0..2) |_| {
            const line = try allocator.alloc(u8, initial_width);
            @memset(line, ' ');
            try lines.append(line);
        }
        var segment_offsets = std.ArrayList(usize).init(allocator);
        try segment_offsets.append(0);
        return Buffer{ .lines = lines, .allocator = allocator, .width = initial_width, .row_count = 1, .segment_offsets = segment_offsets };
    }

    pub fn deinit(self: *Buffer) void {
        for (self.lines.items) |line| {
            self.allocator.free(line);
        }
        self.lines.deinit();
        self.segment_offsets.deinit();
    }

    pub fn getCurrentRow(self: *const Buffer) usize {
        return self.current_row;
    }

    pub fn addRow(self: *Buffer) !void {
        self.current_row += 1;
        if (self.row_count > self.current_row) return;

        const new_line = try self.allocator.alloc(u8, self.width);
        @memset(new_line, ' ');
        try self.lines.append(new_line);
        try self.segment_offsets.append(self.logo_width);
        self.row_count += 1;
    }

    fn write(self: *Buffer, row: usize, col: usize, text: []const u8) !void {
        if (row >= self.row_count) return BufferError.RowOutOfBounds;
        if (col >= self.width) return BufferError.ColumnOutOfBounds;
        const line = self.lines.items[row];
        const end = @min(col + text.len, line.len);
        @memcpy(line[col..end], text[0 .. end - col]);
    }

    pub fn insert(self: *Buffer, text: []const u8) !void {
        try self.write(self.current_row, 0, text);
        try self.addRow();
    }

    pub fn append(self: *Buffer, text: []const u8) !void {
        try self.write(self.current_row, self.segment_offsets.items[self.current_row], text);
        try self.addRow();
    }

    pub fn addComponentRow(self: *Buffer, color: []const u8, label: []const u8, data: []const u8) !void {
        const formatted_label = try std.fmt.allocPrint(self.allocator, "{s}{s}:\x1b[0m ", .{ color, label });
        defer self.allocator.free(formatted_label);

        try self.write(self.current_row, self.segment_offsets.items[self.current_row], formatted_label);
        try self.write(self.current_row, self.segment_offsets.items[self.current_row] + formatted_label.len, data);
        try self.addRow();
    }

    pub fn render(self: *const Buffer, writer: anytype) !void {
        for (self.lines.items[0..self.row_count]) |line| {
            const trimmed_line = std.mem.trimRight(u8, line, " ");
            try writer.print("{s}\n", .{trimmed_line});
        }
    }
};

//================================== Tests =====================================
test "Buffer initialization" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 10);
    defer buffer.deinit();

    try testing.expectEqual(@as(usize, 10), buffer.width);
    try testing.expectEqual(@as(usize, 1), buffer.row_count);
    try testing.expectEqual(@as(usize, 0), buffer.current_row);
}

test "Buffer addRow" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 10);
    defer buffer.deinit();

    try buffer.addRow();
    try testing.expectEqual(@as(usize, 2), buffer.row_count);
    try testing.expectEqual(@as(usize, 1), buffer.current_row);
}

test "Buffer getCurrentRow" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 10);
    defer buffer.deinit();

    try testing.expectEqual(@as(usize, 0), buffer.getCurrentRow());
    try buffer.addRow();
    try testing.expectEqual(@as(usize, 1), buffer.getCurrentRow());
}

test "Buffer insert" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 10);
    defer buffer.deinit();

    try buffer.insert("Hello");
    try testing.expectEqualStrings("Hello     ", buffer.lines.items[0]);
    try testing.expectEqual(@as(usize, 1), buffer.current_row);
}

test "Buffer append" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 10);
    defer buffer.deinit();

    try buffer.append("World");
    try testing.expectEqualStrings("World     ", buffer.lines.items[0][0..]);
    try testing.expectEqual(@as(usize, 1), buffer.current_row);
}

test "Buffer render" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 15);
    defer buffer.deinit();

    try buffer.insert("Hello");
    try buffer.insert("World");

    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    try buffer.render(output.writer());

    const expected = "Hello\nWorld\n\n";
    try testing.expectEqualStrings(expected, output.items);
}

test "Buffer out of bounds" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator, 10);
    defer buffer.deinit();

    try testing.expectError(BufferError.RowOutOfBounds, buffer.write(1, 0, "Test"));
    try testing.expectError(BufferError.ColumnOutOfBounds, buffer.write(0, 10, "Test"));
}
