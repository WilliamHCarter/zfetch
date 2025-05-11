const std = @import("std");

pub const OSResult = struct {
    name: []u8,
    version: []u8,
    build_version: []u8,
};

pub fn parseOS(allocator: std.mem.Allocator) !OSResult {
    const file_path = "/System/Library/CoreServices/SystemVersion.plist";
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));

    var result = OSResult{
        .name = undefined,
        .version = undefined,
        .build_version = undefined,
    };

    const KeyValue = struct { key: []const u8, value: *[]u8 };
    const key_values = [_]KeyValue{
        .{ .key = "ProductName", .value = &result.name },
        .{ .key = "ProductUserVisibleVersion", .value = &result.version },
        .{ .key = "ProductBuildVersion", .value = &result.build_version },
    };

    var found_count: usize = 0;
    var lines = std.mem.split(u8, file_contents, "\n");
    while (lines.next()) |line| {
        const key_start = std.mem.indexOf(u8, line, "<key>") orelse continue;
        const key = line[key_start + 5 .. line.len - 6];

        const value_line = lines.next() orelse continue;
        const value_start = std.mem.indexOf(u8, value_line, "<string>") orelse continue;
        const value = value_line[value_start + 8 .. value_line.len - 9];

        for (key_values) |kv| {
            if (std.mem.eql(u8, key, kv.key)) {
                kv.value.* = try allocator.dupe(u8, value);
                found_count += 1;
                break;
            }
        }
    }

    if (found_count < key_values.len) return error.MissingFields;
    return result;
}
