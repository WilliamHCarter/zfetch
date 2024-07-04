const std = @import("std");
const c = @cImport({
    @cInclude("sys/sysctl.h");
});
const info = @import("../info.zig");

pub fn getHost(allocator: std.mem.Allocator) ![]const u8 {
    const model = try sysctlGetString(allocator, "hw.model");
    defer allocator.free(model);

    const name = getNameFromHwModel(model) orelse model;
    return name;
}

fn sysctlGetString(allocator: std.mem.Allocator, name: [:0]const u8) ![]const u8 {
    var len: usize = 0;
    _ = c.sysctlbyname(name.ptr, null, &len, null, 0);
    if (len == 0) return error.SysctlFailed;

    var buf = try allocator.alloc(u8, len);
    const result = c.sysctlbyname(name.ptr, buf.ptr, &len, null, 0);
    if (result != 0) {
        allocator.free(buf);
        return error.SysctlFailed;
    }

    return buf[0 .. len - 1];
}

fn getNameFromHwModel(model: []const u8) ?[]const u8 {
    const products = info.products;

    inline for (products) |product| {
        if (std.mem.startsWith(u8, model, product[0])) {
            return product[1];
        }
    }

    return null;
}
