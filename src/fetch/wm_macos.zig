const std = @import("std");
const posix = std.posix;
const mem = std.mem;
const ascii = std.ascii;

const CTL_KERN = 1;
const KERN_PROC = 14;
const KERN_PROC_ALL = 0;

pub fn getMacosWM(allocator: mem.Allocator) ![]const u8 {
    const mib = [_]c_int{ CTL_KERN, KERN_PROC, KERN_PROC_ALL };
    var size: usize = 0;

    try posix.sysctl(&mib, null, &size, null, 0);

    const buffer = try allocator.alloc(u8, size);

    try posix.sysctl(&mib, buffer.ptr, &size, null, 0);

    const wm_names = [_][]const u8{ "spectacle", "amethyst", "kwm", "chunkwm", "yabai", "rectangle" };

    var offset: usize = 0;
    while (offset < size) {
        const kinfo_proc = @as(*align(1) const extern struct {
            kp_proc: extern struct {
                p_comm: [16]u8,
            },
            kp_eproc: extern struct {
                e_ppid: i32,
            },
        }, @ptrCast(&buffer[offset]));

        if (kinfo_proc.kp_eproc.e_ppid == 1) {
            const proc_name = mem.sliceTo(&kinfo_proc.kp_proc.p_comm, 0);
            for (wm_names) |wm| {
                if (ascii.eqlIgnoreCase(proc_name, wm)) {
                    var result = try allocator.alloc(u8, wm.len);
                    @memcpy(result, wm);
                    result[0] = ascii.toUpper(result[0]);
                    return result;
                }
            }
        }

        offset += @sizeOf(@TypeOf(kinfo_proc.*));
    }

    return "Quartz Compositor";
}
