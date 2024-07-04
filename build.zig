const std = @import("std");
const builtin = @import("builtin");
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zfetch",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    // Link CoreGraphics framework
    if (builtin.os.tag == .macos) {
        exe.linkFramework("CoreGraphics");
    }

    b.installArtifact(exe);
}
