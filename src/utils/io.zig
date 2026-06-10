//==================================================================================================
// File:       io.zig
// Contents:   The process-wide `std.Io` instance shared by all fetching and rendering.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");

/// `main` replaces this with the runtime's thread-pool implementation before
/// any work begins, which is what makes `process.async` fetches run in
/// parallel. The single-threaded default keeps tests and direct library calls
/// working without setup; their fetches simply run serially.
pub var process: std.Io = std.Io.Threaded.global_single_threaded.io();
