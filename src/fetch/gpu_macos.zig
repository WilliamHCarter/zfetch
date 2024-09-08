const std = @import("std");
const c = @cImport({
    @cInclude("IOKit/IOKitLib.h");
    @cInclude("IOKit/graphics/IOGraphicsLib.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

fn cfStringToZigString(allocator: std.mem.Allocator, cfString: c.CFStringRef) ![]const u8 {
    const length = c.CFStringGetLength(cfString);
    const buffer = try allocator.alloc(u16, @intCast(length));

    c.CFStringGetCharacters(cfString, c.CFRangeMake(0, length), buffer.ptr);

    return try std.unicode.utf16leToUtf8Alloc(allocator, buffer);
}

pub fn getMacosGPU(allocator: std.mem.Allocator) ![]const u8 {
    var iterator: c.io_iterator_t = undefined;
    const result = c.IOServiceGetMatchingServices(c.kIOMasterPortDefault, c.IOServiceMatching(c.kIOAcceleratorClassName), &iterator);
    if (result != c.kIOReturnSuccess) {
        return try allocator.dupe(u8, "GPU Not Found");
    }
    defer _ = c.IOObjectRelease(iterator);

    var registryEntry: c.io_registry_entry_t = c.IOIteratorNext(iterator);
    while (registryEntry != 0) {
        defer _ = c.IOObjectRelease(registryEntry);

        var properties: c.CFMutableDictionaryRef = undefined;
        if (c.IORegistryEntryCreateCFProperties(registryEntry, &properties, c.kCFAllocatorDefault, 0) != c.kIOReturnSuccess) {
            continue;
        }
        defer c.CFRelease(properties);

        const modelKey = c.CFStringCreateWithCString(null, "model", c.kCFStringEncodingUTF8);
        defer c.CFRelease(modelKey);

        if (c.CFDictionaryContainsKey(properties, modelKey) == c.true) {
            const value = c.CFDictionaryGetValue(properties, modelKey);
            if (value != null and c.CFGetTypeID(value) == c.CFStringGetTypeID()) {
                const cfString: c.CFStringRef = @ptrCast(value);
                return cfStringToZigString(allocator, cfString) catch continue;
            }
        } else {
            var parentEntry: c.io_registry_entry_t = undefined;
            if (c.IORegistryEntryGetParentEntry(registryEntry, c.kIOServicePlane, &parentEntry) == c.kIOReturnSuccess) {
                defer _ = c.IOObjectRelease(parentEntry);

                var parentProperties: c.CFMutableDictionaryRef = undefined;
                if (c.IORegistryEntryCreateCFProperties(parentEntry, &parentProperties, c.kCFAllocatorDefault, 0) == c.kIOReturnSuccess) {
                    defer c.CFRelease(parentProperties);

                    if (c.CFDictionaryContainsKey(parentProperties, modelKey) == c.true) {
                        const value = c.CFDictionaryGetValue(parentProperties, modelKey);
                        if (value != null and c.CFGetTypeID(value) == c.CFStringGetTypeID()) {
                            const cfString: c.CFStringRef = @ptrCast(value);
                            return cfStringToZigString(allocator, cfString) catch continue;
                        }
                    }
                }
            }
        }

        registryEntry = c.IOIteratorNext(iterator);
    }

    return try allocator.dupe(u8, "GPU Not Found");
}
