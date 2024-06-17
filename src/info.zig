//==================================================================================================
// File:       info.zig
// Contents:   Information external to the OS used by the program.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");

const VersionError = error{
    InvalidVersion,
    UnknownVersion,
};

pub fn darwinVersionName(version: []const u8) ![]const u8 {
    const version_ranges = &[_][2][]const u8{
        .{ "10.0", "Cheetah" },
        .{ "10.1", "Puma" },
        .{ "10.2", "Jaguar" },
        .{ "10.3", "Panther" },
        .{ "10.4", "Tiger" },
        .{ "10.5", "Leopard" },
        .{ "10.6", "Snow Leopard" },
        .{ "10.7", "Lion" },
        .{ "10.8", "Mountain Lion" },
        .{ "10.9", "Mavericks" },
        .{ "10.10", "Yosemite" },
        .{ "10.11", "El Capitan" },
        .{ "10.12", "Sierra" },
        .{ "10.13", "High Sierra" },
        .{ "10.14", "Mojave" },
        .{ "10.15", "Catalina" },
        .{ "11", "Big Sur" },
        .{ "12", "Monterey" },
        .{ "13", "Ventura" },
    };

    const parsed_version = std.fmt.parseFloat(f32, version) catch return VersionError.InvalidVersion;
    var previous_name: []const u8 = "";

    for (version_ranges) |range| {
        const range_version = std.fmt.parseFloat(f32, range[0]) catch return VersionError.InvalidVersion;
        if (parsed_version >= range_version) {
            previous_name = range[1];
        } else {
            break;
        }
    }

    if (previous_name.len == 0) {
        return VersionError.UnknownVersion;
    }

    return previous_name;
}
