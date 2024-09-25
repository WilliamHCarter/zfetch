const std = @import("std");
const builtin = @import("builtin");
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zfetch",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    // Embed themes
    const embed_themes = b.addOptions();
    embed_themes.addOption([]const u8, "default_theme", @embedFile("themes/default.txt"));
    embed_themes.addOption([]const u8, "minimal_theme", @embedFile("themes/minimal.txt"));

    // Link CoreGraphics framework
    if (builtin.os.tag == .macos) {
        exe.linkFramework("CoreGraphics");
        exe.linkFramework("CoreFoundation");
        exe.linkFramework("CoreVideo");
        exe.linkFramework("IOKit");
    }

    // Link Windows Libraries
    if (builtin.os.tag == .windows) {
        exe.linkLibC();
        exe.linkSystemLibrary("kernel32");
        // exe.linkSystemLibrary("user32");
        // exe.linkSystemLibrary("psapi");
    }
    b.installArtifact(exe);
}
