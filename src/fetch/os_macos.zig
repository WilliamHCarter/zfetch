const std = @import("std");

pub const OSResult = struct {
    name: []u8,
    version: []u8,
    buildVersion: []u8,

    fn deinit(self: *OSResult, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.buildVersion);
    }
};

pub fn parseOS(allocator: std.mem.Allocator) !OSResult {
    const file_path = "/System/Library/CoreServices/SystemVersion.plist";
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(file_contents);

    const keys = [_][]const u8{ "ProductName", "ProductUserVisibleVersion", "ProductBuildVersion" };

    var result = OSResult{
        .name = undefined,
        .version = undefined,
        .buildVersion = undefined,
    };
    var found_count: usize = 0;

    var current_key: ?[]const u8 = null;
    var i: usize = 0;
    while (i < file_contents.len) : (i += 1) {
        if (std.mem.startsWith(u8, file_contents[i..], "<key>")) {
            const key_start = i + 5;
            const key_end = std.mem.indexOfPos(u8, file_contents, key_start, "</key>") orelse continue;
            const key = file_contents[key_start..key_end];

            for (keys) |valid_key| {
                if (std.mem.eql(u8, key, valid_key)) {
                    current_key = valid_key;
                    break;
                }
            }
            i = key_end + 6;
        } else if (std.mem.startsWith(u8, file_contents[i..], "<string>") and current_key != null) {
            const value_start = i + 8;
            const value_end = std.mem.indexOfPos(u8, file_contents, value_start, "</string>") orelse continue;
            const value = try allocator.dupe(u8, file_contents[value_start..value_end]);

            if (std.mem.eql(u8, current_key.?, "ProductName")) {
                result.name = value;
                found_count += 1;
            } else if (std.mem.eql(u8, current_key.?, "ProductUserVisibleVersion")) {
                result.version = value;
                found_count += 1;
            } else if (std.mem.eql(u8, current_key.?, "ProductBuildVersion")) {
                result.buildVersion = value;
                found_count += 1;
            }

            current_key = null;
            i = value_end + 9;
        }

        if (found_count == 3) break;
    }

    if (found_count < 3) {
        result.deinit(allocator);
        return error.MissingFields;
    }

    return result;
}
