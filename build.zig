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

    // Embed logos
    embedLogos(exe, b) catch |err| {
        std.debug.print("failed to embed logos: {any}", .{err});
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
    const wf = b.addWriteFiles();
    var themes_zig = std.ArrayList(u8).init(b.allocator);
    defer themes_zig.deinit();

    try themes_zig.appendSlice(
        \\const std = @import("std");
        \\pub const theme_names = [_][]const u8{
    );

    var dir = try std.fs.cwd().openDir("themes", .{});
    defer dir.close();
    var it = dir.iterate();

    while (try it.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".txt")) {
            const theme_name = if (std.mem.endsWith(u8, entry.name, ".txt"))
                entry.name[0 .. entry.name.len - 4]
            else
                entry.name;
            exe.root_module.addAnonymousImport(theme_name, .{
                .root_source_file = b.path(b.pathJoin(&.{ "themes", entry.name })),
            });
            try themes_zig.writer().print("    \"{s}\",\n", .{theme_name});
        }
    }

    try themes_zig.appendSlice("};");

    const themes_file = wf.add("themes.zig", themes_zig.items);
    exe.root_module.addAnonymousImport("themes", .{ .root_source_file = themes_file });
}

fn embedLogos(exe: *std.Build.Step.Compile, b: *std.Build) !void {
    const wf = b.addWriteFiles();
    var logos_zig = std.ArrayList(u8).init(b.allocator);
    defer logos_zig.deinit();

    try logos_zig.appendSlice(
        \\const std = @import("std");
        \\pub const logo_names = [_][]const u8{
    );

    var dir = try std.fs.cwd().openDir("ascii", .{});
    defer dir.close();
    var it = dir.iterate();

    while (try it.next()) |entry| {
        if (entry.name[0] != '.') {
            const logo_name = entry.name[0 .. entry.name.len - 4];
            exe.root_module.addAnonymousImport(logo_name, .{
                .root_source_file = b.path(b.pathJoin(&.{ "ascii", entry.name })),
            });
            try logos_zig.writer().print("    \"{s}\",\n", .{logo_name});
        }
    }
    try logos_zig.appendSlice("};");

    const logos_file = wf.add("logos.zig", logos_zig.items);
    exe.root_module.addAnonymousImport("logos", .{ .root_source_file = logos_file });
}
