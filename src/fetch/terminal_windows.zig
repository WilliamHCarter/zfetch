const std = @import("std");

pub const TerminalInfo = struct {
    name: []const u8,
    pretty_name: []const u8,
    env_var: []const u8,
};

fn initTerm(name: []const u8, pretty_name: []const u8, env_var: []const u8) TerminalInfo {
    return TerminalInfo{
        .name = name,
        .pretty_name = pretty_name,
        .env_var = env_var,
    };
}

pub fn fetchTerminal(allocator: std.mem.Allocator) !TerminalInfo {
    var info = initTerm("", "Unknown", "");
    if (try fetchFromEnv(allocator, &info)) return info;

    return info;
}

fn envFetchHelper(allocator: std.mem.Allocator, info: *TerminalInfo, temp: TerminalInfo) !bool {
    if (std.process.getEnvVarOwned(allocator, temp.env_var)) |env_value| {
        info.name = try allocator.dupe(u8, temp.name);
        info.pretty_name = if (temp.pretty_name.len > 0)
            try std.fmt.allocPrint(allocator, "{s} ({s})", .{ temp.pretty_name, env_value })
        else
            try allocator.dupe(u8, env_value);
        return true;
    } else |_| {}
    return false;
}

fn fetchFromEnv(allocator: std.mem.Allocator, info: *TerminalInfo) !bool {
    if (try envFetchHelper(allocator, info, initTerm("WindowsTerminal", "Windows Terminal", "WT_SESSION"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("SSH", "SSH", "SSH_TTY"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("MSYS", "MSYS", "MSYSTEM"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Alacritty", "Alacritty", "ALACRITTY_SOCKET"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Alacritty", "Alacritty", "ALACRITTY_LOG"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("Alacritty", "Alacritty", "ALACRITTY_WINDOW_ID"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("TERM", "", "TERM"))) return true;
    if (try envFetchHelper(allocator, info, initTerm("ConEmu", "ConEmu", "ConEmuPID"))) return true;

    if (std.process.getEnvVarOwned(allocator, "TERM_PROGRAM")) |term_program| {
        if (std.mem.eql(u8, term_program, "vscode")) {
            info.name = try allocator.dupe(u8, "Code");
            info.pretty_name = try allocator.dupe(u8, "Visual Studio Code");
            return true;
        }
    } else |_| {}

    return false;
}
