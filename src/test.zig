const std = @import("std");

test {
    _ = @import("commands.zig");
    _ = @import("fetch.zig");
    _ = @import("info.zig");
    _ = @import("layout.zig");
    _ = @import("utils/buffer.zig");
    _ = @import("utils/logo.zig");
}
