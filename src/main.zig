const std = @import("std");
const fetch = @import("fetch.zig");
const layout = @import("layout.zig");

pub fn main() !void {
    const theme_name = "default.txt";
    const theme = try layout.loadTheme("themes/" ++ theme_name);
    try layout.render(theme);
}
