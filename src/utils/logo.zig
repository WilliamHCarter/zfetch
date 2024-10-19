const std = @import("std");
const logo_list = @import("../info.zig").logo_list;

pub const LogoInfo = struct {
    names: []const []const u8,
    colors: []const Color,
    color_primary: ?Color,
    color_secondary: ?Color,
    ascii: ?[]const u8,

    pub fn init(names: []const []const u8, colors: []const Color, color_primary: ?Color, color_secondary: ?Color) LogoInfo {
        return LogoInfo{
            .names = names,
            .colors = colors,
            .color_primary = color_primary,
            .color_secondary = color_secondary,
            .ascii = null,
        };
    }

    pub fn matchNames(self: LogoInfo, name: []const u8) bool {
        for (self.names) |n| {
            if (std.mem.eql(u8, n, name)) {
                return true;
            }
        }
        return false;
    }

    pub fn colorsAsNums(self: LogoInfo) ![]usize {
        var colors = try std.heap.page_allocator.alloc(usize, self.colors.len);

        for (self.colors, 0..) |c, i| {
            colors[i] = @intFromEnum(c);
        }

        return colors;
    }

    pub fn addAscii(self: LogoInfo, ascii: []const u8) LogoInfo {
        return LogoInfo{
            .names = self.names,
            .colors = self.colors,
            .color_primary = self.color_primary,
            .color_secondary = self.color_secondary,
            .ascii = ascii,
        };
    }
};

pub const Color = enum(usize) {
    reset = 0,
    bold = 1,
    dim = 2,
    italic = 3,
    underline = 4,
    blink = 5,
    inverse = 7,
    hidden = 8,
    strikethrough = 9,
    fg_black = 30,
    fg_red = 31,
    fg_green = 32,
    fg_yellow = 33,
    fg_blue = 34,
    fg_magenta = 35,
    fg_cyan = 36,
    fg_white = 37,
    fg_default = 39,
    fg_light_black = 90,
    fg_light_red = 91,
    fg_light_green = 92,
    fg_light_yellow = 93,
    fg_light_blue = 94,
    fg_light_magenta = 95,
    fg_light_cyan = 96,
    fg_light_white = 97,
    bg_black = 40,
    bg_red = 41,
    bg_green = 42,
    bg_yellow = 43,
    bg_blue = 44,
    bg_magenta = 45,
    bg_cyan = 46,
    bg_white = 47,
    bg_default = 49,
    bg_light_black = 100,
    bg_light_red = 101,
    bg_light_green = 102,
    bg_light_yellow = 103,
    bg_light_blue = 104,
    bg_light_magenta = 105,
    bg_light_cyan = 106,
    bg_light_white = 107,
};
