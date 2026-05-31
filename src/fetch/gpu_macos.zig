const std = @import("std");

const mach_port_t = c_uint;
const kern_return_t = c_int;
const io_object_t = mach_port_t;
const io_iterator_t = io_object_t;
const io_registry_entry_t = io_object_t;
const IOOptionBits = u32;

const CFIndex = isize;
const CFTypeID = usize;
const CFStringEncoding = u32;
const CFAllocatorRef = ?*const anyopaque;
const CFTypeRef = ?*const anyopaque;
const CFStringRef = *const anyopaque;
const CFDictionaryRef = *const anyopaque;
const CFMutableDictionaryRef = *anyopaque;
const Boolean = u8;

const CFRange = extern struct {
    location: CFIndex,
    length: CFIndex,
};

const KERN_SUCCESS: kern_return_t = 0;
const kCFStringEncodingUTF8: CFStringEncoding = 0x08000100;
const kIOMainPortDefault: mach_port_t = 0;

extern "c" fn IOServiceMatching(name: [*:0]const u8) ?CFMutableDictionaryRef;
extern "c" fn IOServiceGetMatchingServices(mainPort: mach_port_t, matching: CFDictionaryRef, existing: *io_iterator_t) kern_return_t;
extern "c" fn IOIteratorNext(iterator: io_iterator_t) io_object_t;
extern "c" fn IOObjectRelease(object: io_object_t) kern_return_t;
extern "c" fn IORegistryEntryCreateCFProperties(entry: io_registry_entry_t, properties: *?CFMutableDictionaryRef, allocator: CFAllocatorRef, options: IOOptionBits) kern_return_t;
extern "c" fn IORegistryEntryGetParentEntry(entry: io_registry_entry_t, plane: [*:0]const u8, parent: *io_registry_entry_t) kern_return_t;

extern "c" fn CFStringCreateWithCString(alloc: CFAllocatorRef, cStr: [*:0]const u8, encoding: CFStringEncoding) ?CFStringRef;
extern "c" fn CFStringGetLength(theString: CFStringRef) CFIndex;
extern "c" fn CFStringGetCharacters(theString: CFStringRef, range: CFRange, buffer: [*]u16) void;
extern "c" fn CFStringGetTypeID() CFTypeID;
extern "c" fn CFGetTypeID(cf: CFTypeRef) CFTypeID;
extern "c" fn CFDictionaryContainsKey(theDict: CFDictionaryRef, key: *const anyopaque) Boolean;
extern "c" fn CFDictionaryGetValue(theDict: CFDictionaryRef, key: *const anyopaque) ?*const anyopaque;
extern "c" fn CFRelease(cf: CFTypeRef) void;

fn cfStringToZigString(allocator: std.mem.Allocator, cf_string: CFStringRef) ![]const u8 {
    const length_i = CFStringGetLength(cf_string);
    if (length_i <= 0) return allocator.dupe(u8, "");

    const length: usize = @intCast(length_i);
    const buffer = try allocator.alloc(u16, length);
    defer allocator.free(buffer);

    CFStringGetCharacters(cf_string, .{ .location = 0, .length = length_i }, buffer.ptr);
    return std.unicode.utf16LeToUtf8Alloc(allocator, buffer);
}

fn modelFromProperties(allocator: std.mem.Allocator, properties: CFMutableDictionaryRef, model_key: CFStringRef) !?[]const u8 {
    if (CFDictionaryContainsKey(@ptrCast(properties), @ptrCast(model_key)) == 0) return null;

    const value = CFDictionaryGetValue(@ptrCast(properties), @ptrCast(model_key)) orelse return null;
    if (CFGetTypeID(value) != CFStringGetTypeID()) return null;

    return try cfStringToZigString(allocator, @ptrCast(value));
}

pub fn getMacosGPU(allocator: std.mem.Allocator) ![]const u8 {
    const matching = IOServiceMatching("IOAccelerator") orelse return try allocator.dupe(u8, "GPU Not Found");

    var iterator: io_iterator_t = undefined;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, @ptrCast(matching), &iterator) != KERN_SUCCESS) {
        return try allocator.dupe(u8, "GPU Not Found");
    }
    defer _ = IOObjectRelease(iterator);

    const model_key = CFStringCreateWithCString(null, "model", kCFStringEncodingUTF8) orelse return try allocator.dupe(u8, "GPU Not Found");
    defer CFRelease(@ptrCast(model_key));

    var registry_entry = IOIteratorNext(iterator);
    while (registry_entry != 0) : (registry_entry = IOIteratorNext(iterator)) {
        defer _ = IOObjectRelease(registry_entry);

        var properties: ?CFMutableDictionaryRef = null;
        if (IORegistryEntryCreateCFProperties(registry_entry, &properties, null, 0) == KERN_SUCCESS) {
            if (properties) |props| {
                defer CFRelease(@ptrCast(props));
                if (try modelFromProperties(allocator, props, model_key)) |model| return model;
            }
        }

        var parent_entry: io_registry_entry_t = undefined;
        if (IORegistryEntryGetParentEntry(registry_entry, "IOService", &parent_entry) == KERN_SUCCESS) {
            defer _ = IOObjectRelease(parent_entry);

            var parent_properties: ?CFMutableDictionaryRef = null;
            if (IORegistryEntryCreateCFProperties(parent_entry, &parent_properties, null, 0) == KERN_SUCCESS) {
                if (parent_properties) |parent_props| {
                    defer CFRelease(@ptrCast(parent_props));
                    if (try modelFromProperties(allocator, parent_props, model_key)) |model| return model;
                }
            }
        }
    }

    return try allocator.dupe(u8, "GPU Not Found");
}
