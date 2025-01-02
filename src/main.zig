const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const json = std.json;
const math = std.math;
const mem = std.mem;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cwd = fs.cwd();

    try cwd.deleteTree("site");
    try cwd.makeDir("site");
    const site = try cwd.openDir("site", .{});

    const cname = try cwd.createFile("site/CNAME", .{ .exclusive = true });
    try cname.writeAll("ntbk.xyz");

    try copyFile(
        try cwd.openFile("res/homepage.html", .{}),
        try cwd.createFile("site/index.html", .{ .exclusive = true }),
    );

    try copyDirContents(
        try cwd.openDir("res/images", .{ .iterate = true }),
        site,
    );

    try copyDirContents(
        try cwd.openDir("res/styles", .{ .iterate = true }),
        site,
    );

    try generateSongs(
        allocator,
        try cwd.openDir("res/songs", .{ .iterate = true }),
        site,
    );
}

fn copyFile(from: fs.File, to: fs.File) !void {
    _ = try from.copyRangeAll(0, to, 0, math.maxInt(u64));
}

fn copyDirContents(from: fs.Dir, to: fs.Dir) !void {
    var iter = from.iterate();
    while (try iter.next()) |entry| {
        try copyFile(
            try from.openFile(entry.name, .{}),
            try to.createFile(entry.name, .{ .exclusive = true }),
        );
    }
}

fn generateSongs(allocator: mem.Allocator, songs: fs.Dir, site: fs.Dir) !void {
    var iter = songs.iterate();
    while (try iter.next()) |entry| {
        try generateSong(
            allocator,
            entry.name,
            try songs.openDir(entry.name, .{}),
            site,
        );
    }
}

fn generateSong(allocator: mem.Allocator, name: []const u8, src: fs.Dir, site: fs.Dir) !void {
    const Credit = struct {
        text: []u8,
        link: []u8,
    };

    const Info = struct {
        credit: ?struct {
            original: ?Credit = null,
            samples: ?[]Credit = null,
            ib: ?[]Credit = null,
        } = null,
        description: [][]u8,
        links: struct {
            ntbk: []u8,
            soundcloud: []u8,
            ultrabox: []u8,
        },
    };

    const info = try src.openFile("info.json", .{});
    defer info.close();

    var info_reader = json.reader(allocator, info.reader());
    defer info_reader.deinit();
    const info_json = try json.parseFromTokenSource(Info, allocator, &info_reader, .{});
    defer info_json.deinit();

    try site.makeDir(info_json.value.links.ntbk);
    const dest = try site.openDir(info_json.value.links.ntbk, .{});

    try copyFile(try src.openFile("icon.png", .{}), try dest.createFile("icon.png", .{}));

    const index = try dest.createFile("index.html", .{ .exclusive = true });
    try index.writeAll(
        \\<!doctype HTML>
        \\
        \\<html>
        \\    <head>
        \\        <title>
    );

    try index.writeAll(name);

    try index.writeAll(
        \\</title>
        \\        <link rel="icon" type="image/png" href="icon.png"/>
        \\        <meta charset="UTF-8"/>
        \\        <meta name="description" content="
    );

    const description = info_json.value.description;
    if (description.len > 0) {
        try index.writeAll(description[0]);
        for (info_json.value.description[1..]) |line| {
            try index.writeAll("\n");
            try index.writeAll(line);
        }
    }

    try index.writeAll(
        \\"/>
        \\        <meta name="keywords" content="notebook, ntbk, 
    );

    try index.writeAll(name);

    try index.writeAll(
        \\"/>
        \\        <meta name="author" content="notebook"/>
        \\        <link rel="stylesheet" href="../song.css"/>
        \\    </head>
        \\    <body>
        \\        <div class="box">
        \\            <div class="song-header">
        \\                <img class="song-icon" src="icon.png"/>
        \\                <div class="song-player">
        \\                    <h1 class="song-title">
    );
    try index.writeAll(name);
    try index.writeAll(
        \\</h1>
        \\                    <iframe class="song-embed" src="https://ultraabox.github.io/player/#song=u
    );
    try index.writeAll(info_json.value.links.ultrabox);
    try index.writeAll(
        \\"></iframe>
        \\                </div>
        \\            </div>
        \\
    );
    if (info_json.value.credit) |credit| {
        if (credit.original) |original| {
            try index.writeAll(
                \\            <p class="song-credit">original by <a href="
            );
            try index.writeAll(original.link);
            try index.writeAll(
                \\">
            );
            try index.writeAll(original.text);
            try index.writeAll(
                \\</a>!</p>
                \\
            );
        }

        if (credit.samples) |samples| {
            try index.writeAll(
                \\            <p class="song-credit">with samples from 
            );

            for (samples, 0..) |sample, i| {
                if (i != 0) {
                    if (i == samples.len - 1) {
                        try index.writeAll(" and ");
                    } else {
                        try index.writeAll(", ");
                    }
                }
                try index.writeAll(
                    \\<a href="
                );
                try index.writeAll(sample.link);
                try index.writeAll(
                    \\">
                );
                try index.writeAll(sample.text);
                try index.writeAll(
                    \\</a>
                );
            }

            try index.writeAll(
                \\!</p>
                \\
            );
        }
    }

    for (description) |line| {
        try index.writeAll(
            \\            <p class="song-desc">
        );
        try index.writeAll(line);
        try index.writeAll("</p>\n");
    }

    try index.writeAll(
        \\            <p class="links">
        \\                <a href="https://soundcloud.com/user-505918075/
    );
    try index.writeAll(info_json.value.links.soundcloud);

    try index.writeAll(
        \\">soundcloud</a> |
        \\                <a href="https://ultraabox.github.io/#u
    );
    try index.writeAll(info_json.value.links.ultrabox);

    try index.writeAll(
        \\">ultrabox</a>
        \\            </p>
        \\        </div>
        \\    </body>
        \\</html>
    );
}
