const std = @import("std");
const execCommand = @import("../fetch.zig").execCommand;

pub const TerminalInfo = struct { name: []const u8, pretty_name: []const u8, env_var: []const u8, version: ?[]const u8 };

fn initTerm(name: []const u8, pretty_name: []const u8, env_var: []const u8) TerminalInfo {
    return TerminalInfo{
        .name = name,
        .pretty_name = pretty_name,
        .env_var = env_var,
        .version = null,
    };
}

pub fn fetchTerminal(allocator: std.mem.Allocator) !TerminalInfo {
    var info = initTerm("", "Unknown", "");
    if (try fetchFromEnv(allocator, &info)) return info;
    return info;
}

fn envFetchHelper(allocator: std.mem.Allocator, info: *TerminalInfo, temp: TerminalInfo) !bool {
    if (std.process.getEnvVarOwned(allocator, temp.env_var)) |env_value| {
        defer allocator.free(env_value);
        info.name = try allocator.dupe(u8, temp.name);
        info.version = try getTerminalVersion(allocator, temp);
        info.pretty_name = if (temp.pretty_name.len > 0)
            try std.fmt.allocPrint(allocator, "{s} {s}", .{ temp.pretty_name, info.version.? })
        else
            try allocator.dupe(u8, env_value);
        return true;
    } else |_| {}
    return false;
}

fn fetchFromEnv(allocator: std.mem.Allocator, info: *TerminalInfo) !bool {
    if (try envFetchHelper(allocator, info, initTerm("Gnome", "GNOME Terminal", "GNOME_TERMINAL_SERVICE"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Konsole", "Konsole", "KONSOLE_VERSION"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("XTerm", "XTerm", "XTERM_VERSION"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Alacritty", "Alacritty", "ALACRITTY_LOG"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Terminator", "Terminator", "TERMINATOR_UUID"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Kitty", "Kitty", "KITTY_WINDOW_ID"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Tmux", "Tmux", "TMUX"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Screen", "GNU Screen", "STY"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("SSH", "SSH", "SSH_TTY"))) return true;

    if (std.process.getEnvVarOwned(allocator, "TERM_PROGRAM")) |term_program| {
        defer allocator.free(term_program);
        if (std.mem.eql(u8, term_program, "vscode")) {
            info.name = try allocator.dupe(u8, "Code");
            info.pretty_name = try allocator.dupe(u8, "Visual Studio Code");
            return true;
        } else if (std.mem.eql(u8, term_program, "iTerm.app")) {
            info.name = try allocator.dupe(u8, "iTerm2");
            info.pretty_name = try allocator.dupe(u8, "iTerm2");
            return true;
        }
    } else |_| {}

    if (try envFetchHelper(allocator, info, initTerm("TERM", "", "TERM"))) {
        if (std.mem.startsWith(u8, info.pretty_name, "xterm")) {
            info.name = try allocator.dupe(u8, "XTerm");
            info.pretty_name = try allocator.dupe(u8, "XTerm");
        } else if (std.mem.startsWith(u8, info.pretty_name, "rxvt")) {
            info.name = try allocator.dupe(u8, "RXVT");
            info.pretty_name = try allocator.dupe(u8, "RXVT");
        }
        return true;
    }

    return false;
}

fn getTerminalVersion(allocator: std.mem.Allocator, info: TerminalInfo) ![]const u8 {
    if (std.mem.eql(u8, info.name, "Konsole") or
        std.mem.eql(u8, info.name, "XTerm") or
        std.mem.eql(u8, info.name, "Kitty"))
    {
        return try allocator.dupe(u8, info.env_var);
    }

    if (std.mem.eql(u8, info.name, "Gnome")) {
        const res = try execCommand(allocator, &[_][]const u8{ "gnome-terminal", "--version" }, "");
        const version_start = std.mem.indexOf(u8, res, "GNOME Terminal ") orelse return error.VersionNotFound;
        const version_end = std.mem.indexOfPos(u8, res, version_start + "GNOME Terminal ".len, " ") orelse res.len;
        return try allocator.dupe(u8, res[version_start + "GNOME Terminal ".len .. version_end]);
    }

    return try allocator.dupe(u8, "Unknown");
}
