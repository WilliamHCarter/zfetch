const std = @import("std");
const builtin = @import("builtin");
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zfetch",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    // Embed themes
    const resource_file = b.path("themes/default.txt");
    exe.addIncludePath(resource_file);

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

fn embedThemes(b: *std.Build, options: *std.Build.Step.Options) !void {
    const themes_dir = try std.fs.cwd().openDir("themes", .{ .iterate = true });

    var theme_iter = themes_dir.iterate();
    while (try theme_iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".txt")) continue;

        const theme_name = entry.name[0 .. entry.name.len - 4]; // Remove .txt extension
        const theme_path = try std.fs.path.join(b.allocator, &[_][]const u8{ "themes", entry.name });
        const theme_content = try std.fs.cwd().readFileAlloc(b.allocator, theme_path, 1024 * 1024); // 1MB max

        options.addOption([]const u8, theme_name, theme_content);
    }
}
