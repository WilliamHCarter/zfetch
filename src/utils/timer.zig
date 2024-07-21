const std = @import("std");

pub const LapEntry = struct {
    key: []u8,
    start_time: u64,
    end_time: u64,

    fn deinit(self: *LapEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
    }
};

pub const Timer = struct {
    start_time: u64,
    laps: std.ArrayList(LapEntry),
    timer: std.time.Timer,
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Timer {
        return Timer{
            .start_time = 0,
            .laps = std.ArrayList(LapEntry).init(allocator),
            .timer = try std.time.Timer.start(),
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Timer) void {
        for (self.laps.items) |*lap_item| {
            lap_item.deinit(self.allocator);
        }
        self.laps.deinit();
    }

    pub fn start(self: *Timer) void {
        self.timer.reset();
        self.start_time = self.timer.read();
        self.laps.clearRetainingCapacity();
    }

    pub fn lap(self: *Timer, key: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const current_time = self.timer.read();
        try self.laps.append(LapEntry{
            .key = key,
            .time = @intCast(current_time - self.start_time),
        });
    }
    pub fn end(self: *Timer) u64 {
        return self.timer.read() - self.start_time;
    }

    pub fn startLap(self: *Timer, key: []const u8) !u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const current_time = self.timer.read();
        const lap_start: u64 = @intCast(current_time - self.start_time);
        const owned_key = try self.allocator.dupe(u8, key);
        try self.laps.append(LapEntry{
            .key = owned_key,
            .start_time = lap_start,
            .end_time = 0,
        });
        return lap_start;
    }

    pub fn endLap(self: *Timer, key: []const u8, start_time: u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const current_time = self.timer.read();
        const lap_end: u64 = @intCast(current_time - self.start_time);

        for (self.laps.items) |*lap_item| {
            if (std.mem.eql(u8, lap_item.key, key) and lap_item.start_time == start_time) {
                lap_item.end_time = lap_end;
                break;
            }
        }
    }

    pub fn printResults(self: *Timer, writer: anytype) !void {
        try writer.print("start: 0.00ms\n", .{});
        for (self.laps.items) |lap_entry| {
            try writer.print("{s}: start {d:.2}ms, end {d:.2}ms (duration {d:.2}ms)\n", .{
                lap_entry.key,
                @as(f64, @floatFromInt(lap_entry.start_time)) / std.time.ns_per_ms,
                @as(f64, @floatFromInt(lap_entry.end_time)) / std.time.ns_per_ms,
                @as(f64, @floatFromInt(lap_entry.end_time - lap_entry.start_time)) / std.time.ns_per_ms,
            });
        }
        const total_time = @as(f64, @floatFromInt(self.timer.read() - self.start_time)) / std.time.ns_per_ms;
        try writer.print("end: {d:.2}ms\n", .{total_time});
    }
};
