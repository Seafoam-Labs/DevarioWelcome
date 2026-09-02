const bindings = @import("DevarioWelcome");
const gio = bindings.gio;

const schema_id = "com.devario.welcome";

pub fn getLastPage() []const u8 {
    const settings = gio.Settings.new(schema_id);
    const page = gio.Settings.getString(settings, "last-page");
    return std.mem.sliceTo(page, 0);
}

pub fn setLastPage(page: [*:0]const u8) void {
    const settings = gio.Settings.new(schema_id);
    _ = gio.Settings.setString(settings, "last-page", page);
}

const std = @import("std");
