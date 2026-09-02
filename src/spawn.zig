const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
});

pub fn openUrl(url: [*:0]const u8) void {
    var buf: [512]u8 = undefined;
    const cmd = std.fmt.bufPrintZ(&buf, "xdg-open {s} &", .{url}) catch return;
    _ = c.system(cmd);
}

pub fn launchApp(app: [*:0]const u8) void {
    _ = std.Thread.spawn(.{}, runInThread, .{app}) catch return;
}

fn runInThread(app: [*:0]const u8) void {
    _ = c.system(app);
}
