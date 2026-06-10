const std = @import("std");
const builtin = @import("builtin");

pub const LapEntry = struct {
    key: []u8,
    start_time: u64,
    end_time: u64,

    fn deinit(self: *LapEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
    }
};

/// Wall-clock benchmark timer for the fetch/render pipeline.
///
/// `elapsed` is read-only and safe to call from any task; everything else is
/// single-threaded by design: concurrent tasks time themselves with `elapsed`
/// and hand their numbers back to the coordinating thread, which is the only
/// caller of `recordLap`.
pub const Timer = struct {
    start_time: u64,
    laps: std.array_list.Managed(LapEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Timer {
        return Timer{
            .start_time = now(),
            .laps = std.array_list.Managed(LapEntry).init(allocator),
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
        self.start_time = now();
        self.laps.clearRetainingCapacity();
    }

    /// Nanoseconds since `start`.
    pub fn elapsed(self: *const Timer) u64 {
        return elapsedSince(self.start_time);
    }

    pub fn recordLap(self: *Timer, key: []const u8, lap_start: u64, lap_end: u64) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        try self.laps.append(.{
            .key = owned_key,
            .start_time = lap_start,
            .end_time = lap_end,
        });
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
        const total_time = @as(f64, @floatFromInt(self.elapsed())) / std.time.ns_per_ms;
        try writer.print("end: {d:.2}ms\n", .{total_time});
    }
};

fn elapsedSince(start_time: u64) u64 {
    const current = now();
    return if (current >= start_time) current - start_time else 0;
}

fn now() u64 {
    return switch (builtin.os.tag) {
        .linux => linuxNow(),
        .macos, .ios, .tvos, .watchos, .visionos => posixNow(std.posix.CLOCK.UPTIME_RAW),
        .freebsd, .openbsd, .netbsd, .dragonfly => posixNow(std.posix.CLOCK.MONOTONIC),
        .windows => windowsNow(),
        else => 0,
    };
}

fn linuxNow() u64 {
    var ts: std.os.linux.timespec = undefined;
    const rc = std.os.linux.clock_gettime(.MONOTONIC, &ts);
    if (std.os.linux.errno(rc) != .SUCCESS) return 0;
    return timespecToNs(ts.sec, ts.nsec);
}

fn posixNow(clock_id: std.posix.clockid_t) u64 {
    var ts: std.posix.timespec = undefined;
    if (std.posix.system.clock_gettime(clock_id, &ts) != 0) return 0;
    return timespecToNs(ts.sec, ts.nsec);
}

fn windowsNow() u64 {
    var counter: std.os.windows.LARGE_INTEGER = undefined;
    var frequency: std.os.windows.LARGE_INTEGER = undefined;
    if (!std.os.windows.ntdll.RtlQueryPerformanceCounter(&counter).toBool()) return 0;
    if (!std.os.windows.ntdll.RtlQueryPerformanceFrequency(&frequency).toBool()) return 0;
    if (frequency <= 0) return 0;
    return @intCast(@divTrunc(@as(i128, counter) * std.time.ns_per_s, frequency));
}

fn timespecToNs(sec: anytype, nsec: anytype) u64 {
    const total = @as(i128, sec) * std.time.ns_per_s + nsec;
    return if (total > 0) @intCast(total) else 0;
}
