const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;

pub const HostInfo = struct {
    family: []const u8,
    name: []const u8,
    version: []const u8,
    sku: []const u8,
    serial: []const u8,
    uuid: []const u8,
    vendor: []const u8,
};

pub fn getLinuxHost(allocator: mem.Allocator) ![]const u8 {
    var host = HostInfo{
        .family = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/product_family") orelse "",
        .name = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/product_name") orelse "",
        .version = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/product_version") orelse "",
        .sku = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/product_sku") orelse "",
        .serial = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/product_serial") orelse "",
        .uuid = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/product_uuid") orelse "",
        .vendor = try getFileContent(allocator, "/sys/devices/virtual/dmi/id/sys_vendor") orelse "",
    };

    if (host.name.len == 0) {
        host.name = try getHostProductName(allocator) orelse "";
    }

    if (host.serial.len == 0) {
        host.serial = try getHostSerialNumber(allocator) orelse "";
    }

    if (host.vendor.len == 0 and mem.startsWith(u8, host.name, "Apple ")) {
        host.vendor = "Apple Inc.";
    }

    if (mem.startsWith(u8, host.name, "Standard PC")) {
        var nameBuffer = try allocator.alloc(u8, host.name.len + 9);
        defer allocator.free(nameBuffer);
        @memcpy(nameBuffer[0..9], "KVM/QEMU ");
        @memcpy(nameBuffer[9..], host.name);
        host.name = try allocator.dupe(u8, nameBuffer);
    }

    const wsl_distro_name = std.process.getEnvVarOwned(allocator, "WSL_DISTRO_NAME") catch null;
    if (wsl_distro_name) |wsl_distro| {
        host.name = try std.fmt.allocPrint(allocator, "Windows Subsystem for Linux - {s}", .{wsl_distro});
        host.family = "WSL";
    } else {
        const wsl_distro = std.process.getEnvVarOwned(allocator, "WSL_DISTRO") catch null;
        const wsl_interop = std.process.getEnvVarOwned(allocator, "WSL_INTEROP") catch null;
        if (wsl_distro != null or wsl_interop != null) {
            host.name = "Windows Subsystem for Linux";
            host.family = "WSL";
        }
    }

    return std.fmt.allocPrint(allocator, "{s} {s} {s}", .{
        host.family,
        host.name,
        host.version,
    });
}

fn getFileContent(allocator: mem.Allocator, path: []const u8) !?[]const u8 {
    const file = fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    return mem.trim(u8, content, &std.ascii.whitespace);
}

fn getHostProductName(allocator: mem.Allocator) !?[]const u8 {
    const paths = [_][]const u8{
        "/sys/firmware/devicetree/base/model",
        "/sys/firmware/devicetree/base/banner-name",
        "/tmp/sysinfo/model",
    };

    for (paths) |path| {
        if (try getFileContent(allocator, path)) |content| {
            if (content.len > 0) return content;
        }
    }

    return null;
}

fn getHostSerialNumber(allocator: mem.Allocator) !?[]const u8 {
    return getFileContent(allocator, "/sys/firmware/devicetree/base/serial-number");
}