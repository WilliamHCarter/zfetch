const std = @import("std");
const logo_list = @import("../info.zig").logo_list;
const logos = @import("logos");

pub const Ascii = struct {
    name: []const u8,
    content: []const u8,
};

pub fn getAsciiList() !std.ArrayList(Ascii) {
    var logo_lst = std.ArrayList(Ascii).init(std.heap.page_allocator);
    inline for (logos.names) |name| {
        try logo_lst.append(Ascii{ .name = name, .content = @embedFile(name) });
    }
    return logo_lst;
}

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

    pub fn getLogoFromList(name: []const u8) !LogoInfo {
        var logo: LogoInfo = undefined;
        var logo_found: bool = false;

        for (logo_list) |lg| {
            if (lg.matchNames(name)) {
                logo = lg;
                logo_found = true;
            }
        }
        if (!logo_found) return error.LogoNotFound;
        const ascii_list: std.ArrayList(Ascii) = try getAsciiList();
        for (ascii_list.items) |ascii_item| {
            if (logo.matchNames(ascii_item.name)) {
                return logo.addAscii(ascii_item.content);
            }
        }
        return error.LogoNotFound;
    }

    pub fn getLogoFromFile(filename: []const u8) !LogoInfo {
        var logo: LogoInfo = undefined;

        const file_contents: []const u8 = std.fs.cwd().readFileAlloc(std.heap.page_allocator, filename, std.fs.MAX_PATH_BYTES) catch {
            return error.LogoFileNotFound;
        };
        defer std.heap.page_allocator.free(file_contents);

        const start_marker = "<<<";
        const end_marker = ">>>";

        const start_idx = std.mem.indexOf(u8, file_contents, start_marker) orelse return error.InvalidFormat;
        const end_idx = std.mem.indexOf(u8, file_contents, end_marker) orelse return error.InvalidFormat;

        if (end_idx <= start_idx + start_marker.len) return error.InvalidFormat;

        const metadata = std.mem.trim(u8, file_contents[start_idx + start_marker.len .. end_idx], &std.ascii.whitespace);
        var names = std.ArrayList([]const u8).init(std.heap.page_allocator);
        defer names.deinit();

        var metadata_iter = std.mem.split(u8, metadata, ",");
        while (metadata_iter.next()) |name| {
            const trimmed_name = std.mem.trim(u8, name, &std.ascii.whitespace);
            try names.append(trimmed_name);
        }

        const newline_after_meta = std.mem.indexOf(u8, file_contents[end_idx + end_marker.len ..], "\n") orelse
            return error.InvalidFormat;
        const ascii_start = end_idx + end_marker.len + newline_after_meta + 1;
        const ascii_content = file_contents[ascii_start..];

        logo = LogoInfo{
            .names = try names.toOwnedSlice(),
            .colors = &[_]Color{},
            .color_primary = null,
            .color_secondary = null,
            .ascii = ascii_content,
        };

        return logo;
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
