const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zfetch",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    // Embed themes
    embedThemes(exe, b) catch |err| {
        std.debug.print("failed to embed themes: {any}", .{err});
    };

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

fn embedThemes(exe: *std.Build.Step.Compile, b: *std.Build) !void {
    var dir = try std.fs.cwd().openDir("themes", .{});
    defer dir.close();
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".txt")) {
            const theme_name = if (std.mem.endsWith(u8, entry.name, ".txt"))
                entry.name[0 .. entry.name.len - 4]
            else
                entry.name;
            std.debug.print("Adding theme: {s}\n", .{theme_name});
            exe.root_module.addAnonymousImport(theme_name, .{
                .root_source_file = b.path(b.pathJoin(&.{ "themes", entry.name })),
            });
        }
    }
}
