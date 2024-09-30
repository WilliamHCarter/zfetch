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
    try generateEmbedIndexFile("themes", "themes", exe, b);
}

fn embedLogos(exe: *std.Build.Step.Compile, b: *std.Build) !void {
    try generateEmbedIndexFile("ascii", "logos", exe, b);
}

// Generates a file at compile time storing indexes to embedded files.
// Currently used for indexing logos and themes.
fn generateEmbedIndexFile(path: []const u8, filename: []const u8, exe: *std.Build.Step.Compile, b: *std.Build) !void {
    const wf = b.addWriteFiles();
    var file_lines = std.ArrayList(u8).init(b.allocator);
    defer file_lines.deinit();

    try file_lines.appendSlice(
        \\const std = @import("std");
        \\pub const names = [_][]const u8{
    );

    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();
    var itr = dir.iterate();

    while (try itr.next()) |entry| {
        if (entry.name[0] != '.') {
            const trimmed_name = entry.name[0 .. entry.name.len - 4];
            exe.root_module.addAnonymousImport(trimmed_name, .{
                .root_source_file = b.path(b.pathJoin(&.{ path, entry.name })),
            });
            try file_lines.writer().print("    \"{s}\",\n", .{trimmed_name});
        }
    }
    try file_lines.appendSlice("};");

    const gen_file = wf.add(try std.mem.concat(std.heap.page_allocator, u8, &[_][]const u8{ filename, ".zig" }), file_lines.items);
    exe.root_module.addAnonymousImport(filename, .{ .root_source_file = gen_file });
}
