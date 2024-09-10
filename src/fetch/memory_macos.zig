const std = @import("std");
const c = @cImport({
    @cInclude("sys/sysctl.h");
    @cInclude("mach/mach.h");
    @cInclude("mach/vm_statistics.h");
});

fn sysctlGetU64(name: [:0]const u8) !u64 {
    var value: u64 = 0;
    var size: usize = @sizeOf(u64);
    const result = c.sysctlbyname(name.ptr, &value, &size, null, 0);
    if (result != 0) return error.SysctlFailed;
    return value;
}

pub fn getMachMemoryStats() !u64 {
    const host_port: c.mach_port_t = c.mach_host_self();
    const host_size = @sizeOf(c.vm_statistics64) / @sizeOf(c_int);

    var vm_stat: c.vm_statistics64 = undefined;
    var count: c.mach_msg_type_number_t = host_size;

    const kern_result = c.host_statistics64(host_port, c.HOST_VM_INFO64, @as(c.host_info_t, @ptrCast(&vm_stat)), &count);

    if (kern_result != c.KERN_SUCCESS) {
        return error.HostStatisticsFailed;
    }

    const page_size: u64 = 4096;
    const used_memory: u64 = (vm_stat.active_count + vm_stat.wire_count) * page_size;

    return used_memory * 10;
}
