const std = @import("std");

pub fn getEnvVarOwned(allocator: std.mem.Allocator, key: []const u8) ![]u8 {
    const key_z = try allocator.dupeZ(u8, key);
    defer allocator.free(key_z);

    const value_ptr = std.c.getenv(key_z.ptr) orelse return error.EnvironmentVariableNotFound;
    const value = std.mem.span(value_ptr);
    return allocator.dupe(u8, value);
}
