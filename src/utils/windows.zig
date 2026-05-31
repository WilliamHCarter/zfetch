const std = @import("std");
const windows = std.os.windows;

pub const DWORD = windows.DWORD;
pub const WORD = windows.WORD;
pub const BOOL = windows.BOOL;
pub const WCHAR = u16;
pub const BYTE = windows.BYTE;
pub const DWORDLONG = u64;
pub const LONG = c_long;
pub const ULONG_PTR = usize;
pub const PVOID = ?*anyopaque;

pub const PROCESSOR_ARCHITECTURE_INTEL: WORD = 0;
pub const PROCESSOR_ARCHITECTURE_ARM: WORD = 5;
pub const PROCESSOR_ARCHITECTURE_IA64: WORD = 6;
pub const PROCESSOR_ARCHITECTURE_AMD64: WORD = 9;
pub const PROCESSOR_ARCHITECTURE_ARM64: WORD = 12;
pub const PROCESSOR_ARCHITECTURE_UNKNOWN: WORD = 0xffff;

pub const MEMORYSTATUSEX = extern struct {
    dwLength: DWORD,
    dwMemoryLoad: DWORD,
    ullTotalPhys: DWORDLONG,
    ullAvailPhys: DWORDLONG,
    ullTotalPageFile: DWORDLONG,
    ullAvailPageFile: DWORDLONG,
    ullTotalVirtual: DWORDLONG,
    ullAvailVirtual: DWORDLONG,
    ullAvailExtendedVirtual: DWORDLONG,
};

pub const SYSTEM_INFO = extern struct {
    processor_info: extern union {
        dwOemId: DWORD,
        fields: extern struct {
            wProcessorArchitecture: WORD,
            wReserved: WORD,
        },
    },
    dwPageSize: DWORD,
    lpMinimumApplicationAddress: PVOID,
    lpMaximumApplicationAddress: PVOID,
    dwActiveProcessorMask: ULONG_PTR,
    dwNumberOfProcessors: DWORD,
    dwProcessorType: DWORD,
    dwAllocationGranularity: DWORD,
    wProcessorLevel: WORD,
    wProcessorRevision: WORD,
};

pub const POINTL = extern struct {
    x: LONG,
    y: LONG,
};

pub const DISPLAY_DEVICEW = extern struct {
    cb: DWORD,
    DeviceName: [32]WCHAR,
    DeviceString: [128]WCHAR,
    StateFlags: DWORD,
    DeviceID: [128]WCHAR,
    DeviceKey: [128]WCHAR,
};

pub const DEVMODEW = extern struct {
    dmDeviceName: [32]WCHAR,
    dmSpecVersion: WORD,
    dmDriverVersion: WORD,
    dmSize: WORD,
    dmDriverExtra: WORD,
    dmFields: DWORD,
    display: extern struct {
        dmPosition: POINTL,
        dmDisplayOrientation: DWORD,
        dmDisplayFixedOutput: DWORD,
    },
    dmColor: c_short,
    dmDuplex: c_short,
    dmYResolution: c_short,
    dmTTOption: c_short,
    dmCollate: c_short,
    dmFormName: [32]WCHAR,
    dmLogPixels: WORD,
    dmBitsPerPel: DWORD,
    dmPelsWidth: DWORD,
    dmPelsHeight: DWORD,
    dmDisplayFlags: DWORD,
    dmDisplayFrequency: DWORD,
};

pub extern "kernel32" fn GlobalMemoryStatusEx(lpBuffer: *MEMORYSTATUSEX) BOOL;
pub extern "kernel32" fn GetTickCount64() u64;
pub extern "kernel32" fn GetNativeSystemInfo(lpSystemInfo: *SYSTEM_INFO) void;
pub extern "user32" fn EnumDisplayDevicesW(lpDevice: [*c]const WCHAR, iDevNum: DWORD, lpDisplayDevice: *DISPLAY_DEVICEW, dwFlags: DWORD) BOOL;
pub extern "user32" fn EnumDisplaySettingsW(lpszDeviceName: [*c]const WCHAR, iModeNum: DWORD, lpDevMode: *DEVMODEW) BOOL;
pub extern "user32" fn GetSystemMetrics(nIndex: c_int) c_int;
