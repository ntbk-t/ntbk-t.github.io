const std = @import("std");
const fs = std.fs;

pub fn main() !void {
    const cwd = fs.cwd();
    var assets = try cwd.openDir("assets", .{});
    defer assets.close();

    try cwd.deleteTree("site");
    var site = try cwd.makeOpenPath("site", .{});
    defer site.close();

    try commonFiles(assets, site);
    try makeHomepage(assets, site);
    try make404(assets, site);
}

fn commonFiles(assets: fs.Dir, site: fs.Dir) !void {
    try assets.copyFile("default.ico", site, "default.ico", .{});
    try assets.copyFile("CNAME", site, "CNAME", .{});
}

fn makeHomepage(assets: fs.Dir, site: fs.Dir) !void {
    var assets_homepage = try assets.openDir("homepage", .{});
    defer assets_homepage.close();
    var site_homepage = try site.makeOpenPath("homepage", .{});
    defer site_homepage.close();

    try assets_homepage.copyFile("index.html", site, "index.html", .{});
    try assets_homepage.copyFile("avatar.png", site_homepage, "avatar.png", .{});
    try assets_homepage.copyFile("cool-grid.png", site_homepage, "cool-grid.png", .{});
    try assets_homepage.copyFile("index.css", site_homepage, "index.css", .{});
}

fn make404(assets: fs.Dir, site: fs.Dir) !void {
    var assets_404 = try assets.openDir("404", .{});
    defer assets_404.close();
    var site_404 = try site.makeOpenPath("404", .{});
    defer site_404.close();

    try assets_404.copyFile("index.html", site_404, "index.html", .{});
    try assets_404.copyFile("ominous-fog.png", site_404, "ominous-fog.png", .{});
}
