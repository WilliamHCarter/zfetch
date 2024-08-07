//==================================================================================================
// File:       info.zig
// Contents:   Information external to the OS used by the program.
// Author:     Will Carter
//==================================================================================================

const std = @import("std");

const VersionError = error{
    InvalidVersion,
    UnknownVersion,
};

pub fn darwinVersionName(version: []const u8) ![]const u8 {
    const version_ranges = &[_][2][]const u8{
        .{ "10.0", "Cheetah" },
        .{ "10.1", "Puma" },
        .{ "10.2", "Jaguar" },
        .{ "10.3", "Panther" },
        .{ "10.4", "Tiger" },
        .{ "10.5", "Leopard" },
        .{ "10.6", "Snow Leopard" },
        .{ "10.7", "Lion" },
        .{ "10.8", "Mountain Lion" },
        .{ "10.9", "Mavericks" },
        .{ "10.10", "Yosemite" },
        .{ "10.11", "El Capitan" },
        .{ "10.12", "Sierra" },
        .{ "10.13", "High Sierra" },
        .{ "10.14", "Mojave" },
        .{ "10.15", "Catalina" },
        .{ "11", "Big Sur" },
        .{ "12", "Monterey" },
        .{ "13", "Ventura" },
    };

    const parsed_version = std.fmt.parseFloat(f32, version) catch return VersionError.InvalidVersion;
    var previous_name: []const u8 = "";

    for (version_ranges) |range| {
        const range_version = std.fmt.parseFloat(f32, range[0]) catch return VersionError.InvalidVersion;
        if (parsed_version >= range_version) {
            previous_name = range[1];
        } else {
            break;
        }
    }

    if (previous_name.len == 0) {
        return VersionError.UnknownVersion;
    }

    return previous_name;
}

pub const products = .{
    // MacBook Pro
    .{ "MacBookPro18,3", "MacBook Pro (14-inch, 2021)" },
    .{ "MacBookPro18,4", "MacBook Pro (14-inch, 2021)" },
    .{ "MacBookPro18,1", "MacBook Pro (16-inch, 2021)" },
    .{ "MacBookPro18,2", "MacBook Pro (16-inch, 2021)" },
    .{ "MacBookPro17,1", "MacBook Pro (13-inch, M1, 2020)" },
    .{ "MacBookPro16,4", "MacBook Pro (16-inch, 2019)" },
    .{ "MacBookPro16,3", "MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports)" },
    .{ "MacBookPro16,2", "MacBook Pro (13-inch, 2020, Four Thunderbolt 3 ports)" },
    .{ "MacBookPro16,1", "MacBook Pro (16-inch, 2019)" },
    .{ "MacBookPro15,4", "MacBook Pro (13-inch, 2019, Two Thunderbolt 3 ports)" },
    .{ "MacBookPro15,3", "MacBook Pro (15-inch, 2019)" },
    .{ "MacBookPro15,2", "MacBook Pro (13-inch, 2018/2019, Four Thunderbolt 3 ports)" },
    .{ "MacBookPro15,1", "MacBook Pro (15-inch, 2018/2019)" },
    .{ "MacBookPro14,3", "MacBook Pro (15-inch, 2017)" },
    .{ "MacBookPro14,2", "MacBook Pro (13-inch, 2017, Four Thunderbolt 3 ports)" },
    .{ "MacBookPro14,1", "MacBook Pro (13-inch, 2017, Two Thunderbolt 3 ports)" },
    .{ "MacBookPro13,3", "MacBook Pro (15-inch, 2016)" },
    .{ "MacBookPro13,2", "MacBook Pro (13-inch, 2016, Four Thunderbolt 3 ports)" },
    .{ "MacBookPro13,1", "MacBook Pro (13-inch, 2016, Two Thunderbolt 3 ports)" },
    .{ "MacBookPro12,1", "MacBook Pro (Retina, 13-inch, Early 2015)" },
    .{ "MacBookPro11,4", "MacBook Pro (Retina, 15-inch, Mid 2015)" },
    .{ "MacBookPro11,5", "MacBook Pro (Retina, 15-inch, Mid 2015)" },
    .{ "MacBookPro11,2", "MacBook Pro (Retina, 15-inch, Late 2013/Mid 2014)" },
    .{ "MacBookPro11,3", "MacBook Pro (Retina, 15-inch, Late 2013/Mid 2014)" },
    .{ "MacBookPro11,1", "MacBook Pro (Retina, 13-inch, Late 2013/Mid 2014)" },
    .{ "MacBookPro10,2", "MacBook Pro (Retina, 13-inch, Late 2012/Early 2013)" },
    .{ "MacBookPro10,1", "MacBook Pro (Retina, 15-inch, Mid 2012/Early 2013)" },
    .{ "MacBookPro9,2", "MacBook Pro (13-inch, Mid 2012)" },
    .{ "MacBookPro9,1", "MacBook Pro (15-inch, Mid 2012)" },
    .{ "MacBookPro8,3", "MacBook Pro (17-inch, 2011)" },
    .{ "MacBookPro8,2", "MacBook Pro (15-inch, 2011)" },
    .{ "MacBookPro8,1", "MacBook Pro (13-inch, 2011)" },
    .{ "MacBookPro7,1", "MacBook Pro (13-inch, Mid 2010)" },
    .{ "MacBookPro6,2", "MacBook Pro (15-inch, Mid 2010)" },
    .{ "MacBookPro6,1", "MacBook Pro (17-inch, Mid 2010)" },
    .{ "MacBookPro5,5", "MacBook Pro (13-inch, Mid 2009)" },
    .{ "MacBookPro5,3", "MacBook Pro (15-inch, Mid 2009)" },
    .{ "MacBookPro5,2", "MacBook Pro (17-inch, Mid/Early 2009)" },
    .{ "MacBookPro5,1", "MacBook Pro (15-inch, Late 2008)" },
    .{ "MacBookPro4,1", "MacBook Pro (17/15-inch, Early 2008)" },

    // MacBook Air
    .{ "MacBookAir10,1", "MacBook Air (M1, 2020)" },
    .{ "MacBookAir9,1", "MacBook Air (Retina, 13-inch, 2020)" },
    .{ "MacBookAir8,2", "MacBook Air (Retina, 13-inch, 2019)" },
    .{ "MacBookAir8,1", "MacBook Air (Retina, 13-inch, 2018)" },
    .{ "MacBookAir7,2", "MacBook Air (13-inch, Early 2015/2017)" },
    .{ "MacBookAir7,1", "MacBook Air (11-inch, Early 2015)" },
    .{ "MacBookAir6,2", "MacBook Air (13-inch, Mid 2013/Early 2014)" },
    .{ "MacBookAir6,1", "MacBook Air (11-inch, Mid 2013/Early 2014)" },
    .{ "MacBookAir5,2", "MacBook Air (13-inch, Mid 2012)" },
    .{ "MacBookAir5,1", "MacBook Air (11-inch, Mid 2012)" },
    .{ "MacBookAir4,2", "MacBook Air (13-inch, Mid 2011)" },
    .{ "MacBookAir4,1", "MacBook Air (11-inch, Mid 2011)" },
    .{ "MacBookAir3,2", "MacBook Air (13-inch, Late 2010)" },
    .{ "MacBookAir3,1", "MacBook Air (11-inch, Late 2010)" },
    .{ "MacBookAir2,1", "MacBook Air (Mid 2009)" },

    // Mac mini
    .{ "Macmini9,1", "Mac mini (M1, 2020)" },
    .{ "Macmini8,1", "Mac mini (2018)" },
    .{ "Macmini7,1", "Mac mini (Mid 2014)" },
    .{ "Macmini6,1", "Mac mini (Late 2012)" },
    .{ "Macmini6,2", "Mac mini (Late 2012)" },
    .{ "Macmini5,1", "Mac mini (Mid 2011)" },
    .{ "Macmini5,2", "Mac mini (Mid 2011)" },
    .{ "Macmini4,1", "Mac mini (Mid 2010)" },
    .{ "Macmini3,1", "Mac mini (Early/Late 2009)" },

    // MacBook
    .{ "MacBook10,1", "MacBook (Retina, 12-inch, 2017)" },
    .{ "MacBook9,1", "MacBook (Retina, 12-inch, Early 2016)" },
    .{ "MacBook8,1", "MacBook (Retina, 12-inch, Early 2015)" },
    .{ "MacBook7,1", "MacBook (13-inch, Mid 2010)" },
    .{ "MacBook6,1", "MacBook (13-inch, Late 2009)" },
    .{ "MacBook5,2", "MacBook (13-inch, Early/Mid 2009)" },

    // Mac Pro
    .{ "MacPro7,1", "Mac Pro (2019)" },
    .{ "MacPro6,1", "Mac Pro (Late 2013)" },
    .{ "MacPro5,1", "Mac Pro (Mid 2010 - Mid 2012)" },
    .{ "MacPro4,1", "Mac Pro (Early 2009)" },

    // iMac
    .{ "iMac21,1", "iMac (24-inch, M1, 2021, Two Thunderbolt / USB 4 ports, Two USB 3 ports)" },
    .{ "iMac21,2", "iMac (24-inch, M1, 2021, Two Thunderbolt / USB 4 ports)" },
    .{ "iMac20,1", "iMac (Retina 5K, 27-inch, 2020)" },
    .{ "iMac20,2", "iMac (Retina 5K, 27-inch, 2020)" },
    .{ "iMac19,1", "iMac (Retina 5K, 27-inch, 2019)" },
    .{ "iMac19,2", "iMac (Retina 4K, 21.5-inch, 2019)" },
    .{ "iMacPro1,1", "iMac Pro (2017)" },
    .{ "iMac18,3", "iMac (Retina 5K, 27-inch, 2017)" },
    .{ "iMac18,2", "iMac (Retina 4K, 21.5-inch, 2017)" },
    .{ "iMac18,1", "iMac (21.5-inch, 2017)" },
    .{ "iMac17,1", "iMac (Retina 5K, 27-inch, Late 2015)" },
    .{ "iMac16,2", "iMac (Retina 4K, 21.5-inch, Late 2015)" },
    .{ "iMac16,1", "iMac (21.5-inch, Late 2015)" },
    .{ "iMac15,1", "iMac (Retina 5K, 27-inch, Late 2014 - Mid 2015)" },
    .{ "iMac14,4", "iMac (21.5-inch, Mid 2014)" },
    .{ "iMac14,2", "iMac (27-inch, Late 2013)" },
    .{ "iMac14,1", "iMac (21.5-inch, Late 2013)" },
    .{ "iMac13,2", "iMac (27-inch, Late 2012)" },
    .{ "iMac13,1", "iMac (21.5-inch, Late 2012)" },
    .{ "iMac12,2", "iMac (27-inch, Mid 2011)" },
    .{ "iMac12,1", "iMac (21.5-inch, Mid 2011)" },
    .{ "iMac11,3", "iMac (27-inch, Mid 2010)" },
    .{ "iMac11,2", "iMac (21.5-inch, Mid 2010)" },
    .{ "iMac10,1", "iMac (27/21.5-inch, Late 2009)" },
    .{ "iMac9,1", "iMac (24/20-inch, Early 2009)" },

    // Newer models (2023-2024)
    .{ "Mac15,13", "MacBook Air (15-inch, M3, 2024)" },
    .{ "Mac15,2", "MacBook Air (13-inch, M3, 2024)" },
    .{ "Mac15,3", "MacBook Pro (14-inch, Nov 2023, Two Thunderbolt / USB 4 ports)" },
    .{ "Mac15,4", "iMac (24-inch, 2023, Two Thunderbolt / USB 4 ports)" },
    .{ "Mac15,5", "iMac (24-inch, 2023, Two Thunderbolt / USB 4 ports, Two USB 3 ports)" },
    .{ "Mac15,6", "MacBook Pro (14-inch, Nov 2023, Three Thunderbolt 4 ports)" },
    .{ "Mac15,8", "MacBook Pro (14-inch, Nov 2023, Three Thunderbolt 4 ports)" },
    .{ "Mac15,10", "MacBook Pro (14-inch, Nov 2023, Three Thunderbolt 4 ports)" },
    .{ "Mac15,7", "MacBook Pro (16-inch, Nov 2023, Three Thunderbolt 4 ports)" },
    .{ "Mac15,9", "MacBook Pro (16-inch, Nov 2023, Three Thunderbolt 4 ports)" },
    .{ "Mac15,11", "MacBook Pro (16-inch, Nov 2023, Three Thunderbolt 4 ports)" },
    .{ "Mac14,15", "MacBook Air (15-inch, M2, 2023)" },
    .{ "Mac14,14", "Mac Studio (M2 Ultra, 2023, Two Thunderbolt 4 front ports)" },
    .{ "Mac14,13", "Mac Studio (M2 Max, 2023, Two USB-C front ports)" },
    .{ "Mac14,8", "Mac Pro (2023)" },
    .{ "Mac14,6", "MacBook Pro (16-inch, 2023)" },
    .{ "Mac14,10", "MacBook Pro (16-inch, 2023)" },
    .{ "Mac14,5", "MacBook Pro (14-inch, 2023)" },
    .{ "Mac14,9", "MacBook Pro (14-inch, 2023)" },
    .{ "Mac14,3", "Mac mini (M2, 2023, Two Thunderbolt 4 ports)" },
    .{ "Mac14,12", "Mac mini (M2, 2023, Four Thunderbolt 4 ports)" },
    .{ "Mac14,7", "MacBook Pro (13-inch, M2, 2022)" },
    .{ "Mac14,2", "MacBook Air (M2, 2022)" },
    .{ "Mac13,1", "Mac Studio (M1 Max, 2022, Two USB-C front ports)" },
    .{ "Mac13,2", "Mac Studio (M1 Ultra, 2022, Two Thunderbolt 4 front ports)" },
};