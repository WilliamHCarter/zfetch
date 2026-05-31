const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addEmbeddedAssets(exe_module, b);
    linkPlatformLibraries(exe_module, target.result.os.tag);

    const exe = b.addExecutable(.{
        .name = "zfetch",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    addEmbeddedAssets(test_module, b);
    linkPlatformLibraries(test_module, target.result.os.tag);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const run_smoke = b.addRunArtifact(exe);
    run_smoke.addArg("--help");
    const smoke_step = b.step("smoke", "Run a minimal CLI smoke test");
    smoke_step.dependOn(&run_smoke.step);
}

fn addEmbeddedAssets(module: *std.Build.Module, b: *std.Build) void {
    embedThemes(module, b) catch |err| {
        std.debug.panic("failed to embed themes: {any}", .{err});
    };

    embedLogos(module, b) catch |err| {
        std.debug.panic("failed to embed logos: {any}", .{err});
    };
}

fn linkPlatformLibraries(module: *std.Build.Module, os: std.Target.Os.Tag) void {
    module.linkSystemLibrary("c", .{});
    switch (os) {
        .macos => {
            module.addSystemFrameworkPath(.{ .cwd_relative = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks" });
            module.addLibraryPath(.{ .cwd_relative = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib" });
            module.addSystemFrameworkPath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks" });
            module.addLibraryPath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib" });

            module.linkFramework("CoreGraphics", .{});
            module.linkFramework("CoreFoundation", .{});
            module.linkFramework("CoreVideo", .{});
            module.linkFramework("IOKit", .{});
        },
        .windows => {
            module.linkSystemLibrary("advapi32", .{});
            module.linkSystemLibrary("dwmapi", .{});
            module.linkSystemLibrary("kernel32", .{});
            module.linkSystemLibrary("user32", .{});
        },
        else => {},
    }
}

fn embedThemes(module: *std.Build.Module, b: *std.Build) !void {
    try generateEmbedIndexFile("themes", "themes", module, b);
}

fn embedLogos(module: *std.Build.Module, b: *std.Build) !void {
    try generateEmbedIndexFile("ascii", "logos", module, b);
}

// Generates a file at compile time storing indexes to embedded files.
// Currently used for indexing logos and themes.
fn generateEmbedIndexFile(path: []const u8, filename: []const u8, module: *std.Build.Module, b: *std.Build) !void {
    const wf = b.addWriteFiles();
    var file_lines = std.array_list.Managed(u8).init(b.allocator);
    defer file_lines.deinit();

    try file_lines.appendSlice(
        \\const std = @import("std");
        \\pub const names = [_][]const u8{
    );

    var dir = try std.Io.Dir.cwd().openDir(b.graph.io, path, .{ .iterate = true });
    defer dir.close(b.graph.io);
    var itr = dir.iterate();

    while (try itr.next(b.graph.io)) |entry| {
        if (entry.name[0] != '.') {
            const trimmed_name = entry.name[0 .. entry.name.len - 4];
            module.addAnonymousImport(trimmed_name, .{
                .root_source_file = b.path(b.pathJoin(&.{ path, entry.name })),
            });
            try file_lines.print("    \"{s}\",\n", .{trimmed_name});
        }
    }
    try file_lines.appendSlice("};");

    const generated_filename = try std.mem.concat(std.heap.page_allocator, u8, &[_][]const u8{ filename, ".zig" });
    const generated_file = wf.add(generated_filename, file_lines.items);
    module.addAnonymousImport(filename, .{ .root_source_file = generated_file });
}
