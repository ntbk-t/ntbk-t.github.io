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

    try copyFile(
        try cwd.openFile("res/404.html", .{}),
        try cwd.createFile("site/404.html", .{ .exclusive = true }),
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
    try site.makeDir("music");
    const music = try site.createFile("music/index.html", .{});

    try music.writeAll(
        \\<!doctype HTML>
        \\
        \\<html>
        \\    <head>
        \\        <title>music!</title>
        \\        <meta charset="UTF-8">
        \\        <meta name="description" content="all of my music! in (SOME ORDER IDK LOL)">
        \\        <meta name="keywords" content="notebook, ntbk, music">
        \\        <meta name="author" content="notebook"/>
        \\        <link rel="stylesheet" href="../song.css"/>
        \\        <link rel="icon" type="image/png" href="../default.ico"/>
        \\    </head>
        \\    <body>
    );

    var iter = songs.iterate();
    while (try iter.next()) |entry| {
        var src = try songs.openDir(entry.name, .{});
        defer src.close();

        const song = try ParsedSong.from(allocator, entry.name, src);
        defer song.deinit();

        try generateSong(song, src, site);

        const icon = try mem.concat(allocator, u8, &.{ "../", song.info.value.links.ntbk, "/icon.png" });
        defer allocator.free(icon);

        if (!song.info.value.secret) {
            try writeSongInto(music.writer(), icon, song);
        }
    }

    try writeUltraboxDisclaimer(music.writer());
    try music.writeAll(
        \\    </body>
        \\</html>
    );
}

const SongInfo = struct {
    const Credit = struct {
        text: []u8,
        link: []u8,
    };

    credit: ?struct {
        original: ?Credit = null,
        samples: ?[]Credit = null,
        ib: ?[]Credit = null,
    } = null,
    description: [][]u8,
    links: struct {
        ntbk: []u8,
        soundcloud: ?[]u8 = null,
        ultrabox: []u8,
    },
    secret: bool = false,
};

const ParsedSong = struct {
    name: []const u8,
    info: json.Parsed(SongInfo),

    fn from(allocator: mem.Allocator, name: []const u8, src: fs.Dir) !ParsedSong {
        const info = try src.openFile("info.json", .{});
        defer info.close();

        var info_reader = json.reader(allocator, info.reader());
        defer info_reader.deinit();
        const info_json = try json.parseFromTokenSource(SongInfo, allocator, &info_reader, .{});

        return .{
            .name = name,
            .info = info_json,
        };
    }

    fn deinit(self: ParsedSong) void {
        self.info.deinit();
    }
};

fn generateSong(song: ParsedSong, src: fs.Dir, site: fs.Dir) !void {
    try site.makeDir(song.info.value.links.ntbk);
    const dest = try site.openDir(song.info.value.links.ntbk, .{});

    try copyFile(try src.openFile("icon.png", .{}), try dest.createFile("icon.png", .{}));

    const index = try dest.createFile("index.html", .{ .exclusive = true });
    try index.writeAll(
        \\<!doctype HTML>
        \\
        \\<html>
        \\    <head>
        \\        <title>
    );

    try index.writeAll(song.name);

    try index.writeAll(
        \\</title>
        \\        <link rel="icon" type="image/png" href="icon.png"/>
        \\        <meta charset="UTF-8"/>
        \\        <meta name="description" content="
    );

    const description = song.info.value.description;
    if (description.len > 0) {
        try index.writeAll(description[0]);
        for (song.info.value.description[1..]) |line| {
            try index.writeAll("\n");
            try index.writeAll(line);
        }
    }

    try index.writeAll(
        \\"/>
        \\        <meta name="keywords" content="notebook, ntbk, 
    );

    try index.writeAll(song.name);

    try index.writeAll(
        \\"/>
        \\        <meta name="author" content="notebook"/>
        \\        <link rel="stylesheet" href="
    );

    if (song.info.value.secret) {
        try index.writeAll("../secret_song.css");
    } else {
        try index.writeAll("../song.css");
    }

    try index.writeAll(
        \\"/>
        \\    </head>
        \\    <body>
        \\
    );

    try writeSongInto(index.writer(), "icon.png", song);
    try writeUltraboxDisclaimer(index.writer());

    try index.writeAll(
        \\
        \\    </body>
        \\</html>
    );
}

fn writeSongInto(writer: fs.File.Writer, icon: []const u8, song: ParsedSong) !void {
    try writer.writeAll(
        \\        <div class="box">
        \\            <div class="song-header">
        \\                <img class="song-icon" src="
    );
    try writer.writeAll(icon);
    try writer.writeAll(
        \\"/>
        \\                <div class="song-player">
        \\                    <h1 class="song-title">
    );
    try writer.writeAll(song.name);
    try writer.writeAll(
        \\</h1>
        \\                    <iframe class="song-embed" src="https://ultraabox.github.io/player/#song=u
    );
    try writer.writeAll(song.info.value.links.ultrabox);
    try writer.writeAll(
        \\"></iframe>
        \\                </div>
        \\            </div>
        \\
    );
    if (song.info.value.credit) |credit| {
        if (credit.original) |original| {
            try writer.writeAll(
                \\            <p class="song-credit">original by <a href="
            );
            try writer.writeAll(original.link);
            try writer.writeAll(
                \\">
            );
            try writer.writeAll(original.text);
            try writer.writeAll(
                \\</a>!</p>
                \\
            );
        }

        if (credit.samples) |samples| {
            try writer.writeAll(
                \\            <p class="song-credit">with samples from 
            );

            for (samples, 0..) |sample, i| {
                if (i != 0) {
                    if (i == samples.len - 1) {
                        try writer.writeAll(" and ");
                    } else {
                        try writer.writeAll(", ");
                    }
                }
                try writer.writeAll(
                    \\<a href="
                );
                try writer.writeAll(sample.link);
                try writer.writeAll(
                    \\">
                );
                try writer.writeAll(sample.text);
                try writer.writeAll(
                    \\</a>
                );
            }

            try writer.writeAll(
                \\!</p>
                \\
            );
        }
    }

    for (song.info.value.description) |line| {
        try writer.writeAll(
            \\            <p class="song-desc">
        );
        try writer.writeAll(line);
        try writer.writeAll("</p>\n");
    }

    try writer.writeAll(
        \\            <p class="links">
    );

    if (song.info.value.links.soundcloud) |link| {
        try writer.writeAll(
            \\                <a href="https://soundcloud.com/user-505918075/
        );
        try writer.writeAll(link);

        try writer.writeAll(
            \\">soundcloud</a> |
        );
    }

    try writer.writeAll(
        \\                <a href="https://ultraabox.github.io/#u
    );
    try writer.writeAll(song.info.value.links.ultrabox);

    try writer.writeAll(
        \\">ultrabox</a>
        \\            </p>
        \\        </div>
    );
}

fn writeUltraboxDisclaimer(writer: fs.File.Writer) !void {
    try writer.writeAll(
        \\<p class="centered whisper">
        \\    <a class="whisper" href="https://bsky.app/profile/filegarden.com/post/3lhvw2zv5is23">filegarden is currently down!</a>
        \\    some ultrabox links may not work at the moment...
        \\    (i am going to strategically place legos around John GoDaddy's home)
        \\</p>
    );
}
