const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zfetch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addEmbeddedAssets(exe, b);
    linkPlatformLibraries(exe, target.result.os.tag);

    b.installArtifact(exe);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    addEmbeddedAssets(unit_tests, b);
    linkPlatformLibraries(unit_tests, target.result.os.tag);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const run_smoke = b.addRunArtifact(exe);
    run_smoke.addArg("--help");
    const smoke_step = b.step("smoke", "Run a minimal CLI smoke test");
    smoke_step.dependOn(&run_smoke.step);
}

fn addEmbeddedAssets(exe: *std.Build.Step.Compile, b: *std.Build) void {
    embedThemes(exe, b) catch |err| {
        std.debug.panic("failed to embed themes: {any}", .{err});
    };

    embedLogos(exe, b) catch |err| {
        std.debug.panic("failed to embed logos: {any}", .{err});
    };
}

fn linkPlatformLibraries(exe: *std.Build.Step.Compile, os: std.Target.Os.Tag) void {
    switch (os) {
        .macos => {
            exe.linkFramework("CoreGraphics");
            exe.linkFramework("CoreFoundation");
            exe.linkFramework("CoreVideo");
            exe.linkFramework("IOKit");
        },
        .windows => {
            exe.linkLibC();
            exe.linkSystemLibrary("advapi32");
            exe.linkSystemLibrary("dwmapi");
            exe.linkSystemLibrary("kernel32");
            exe.linkSystemLibrary("user32");
        },
        else => {},
    }
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

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
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

    const generated_filename = try std.mem.concat(std.heap.page_allocator, u8, &[_][]const u8{ filename, ".zig" });
    const generated_file = wf.add(generated_filename, file_lines.items);
    exe.root_module.addAnonymousImport(filename, .{ .root_source_file = generated_file });
}
