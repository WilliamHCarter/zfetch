const std = @import("std");

const mach_port_t = c_uint;
const mach_msg_type_number_t = c_uint;
const host_info_t = [*]c_int;

const KERN_SUCCESS = 0;
const HOST_VM_INFO64 = 4;

const VmStatistics64 = extern struct {
    free_count: u32,
    active_count: u32,
    inactive_count: u32,
    wire_count: u32,
    zero_fill_count: u64,
    reactivations: u64,
    pageins: u64,
    pageouts: u64,
    faults: u64,
    cow_faults: u64,
    lookups: u64,
    hits: u64,
    purges: u64,
    purgeable_count: u32,
    speculative_count: u32,
    decompressions: u64,
    compressions: u64,
    swapins: u64,
    swapouts: u64,
    compressor_page_count: u32,
    throttled_count: u32,
    external_page_count: u32,
    internal_page_count: u32,
    total_uncompressed_pages_in_compressor: u64,
    swapped_count: u64,
    total_tag_storage_pages: u64,
    nontag_pageable_tag_storage_pages: u64,
    nontag_wired_tag_storage_pages: u64,
    free_tag_storage_pages: u64,
    tag_storing_tag_storage_pages: u64,
    total_tagged_pages: u64,
    resident_tagged_pages: u64,
    compressed_tagged_pages: u64,
    tagged_compressions: u64,
    tagged_decompressions: u64,
    compressed_tag_storage_bytes: u64,
};

extern "c" fn mach_host_self() mach_port_t;
extern "c" fn host_statistics64(host_priv: mach_port_t, flavor: c_int, host_info_out: host_info_t, host_info_outCnt: *mach_msg_type_number_t) c_int;
extern "c" fn sysctlbyname(name: [*:0]const u8, oldp: ?*anyopaque, oldlenp: *usize, newp: ?*anyopaque, newlen: usize) c_int;

fn sysctlGetU64(name: [:0]const u8) !u64 {
    var value: u64 = 0;
    var size: usize = @sizeOf(u64);
    const result = sysctlbyname(name.ptr, &value, &size, null, 0);
    if (result != 0) return error.SysctlFailed;
    return value;
}

pub fn getMachMemoryStats() !u64 {
    const host_port = mach_host_self();
    const host_size: mach_msg_type_number_t = @intCast(@sizeOf(VmStatistics64) / @sizeOf(c_int));

    var vm_stat: VmStatistics64 = undefined;
    var count = host_size;
    const kern_result = host_statistics64(host_port, HOST_VM_INFO64, @ptrCast(&vm_stat), &count);

    if (kern_result != KERN_SUCCESS) {
        return error.HostStatisticsFailed;
    }

    const page_size = sysctlGetU64("hw.pagesize") catch 4096;
    return (@as(u64, vm_stat.active_count) + @as(u64, vm_stat.wire_count)) * page_size;
}
