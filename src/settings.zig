const std = @import("std");
const bindings = @import("DevarioWelcome");
const gio = bindings.gio;

const schema_id = "com.devario.welcome";

var cached_settings: ?*gio.Settings = null;

fn getSettings() ?*gio.Settings {
    if (cached_settings) |s| return s;
    const source = gio.SettingsSchemaSource.getDefault() orelse return null;
    const schema = gio.SettingsSchemaSource.lookup(source, schema_id, 1) orelse return null;
    const settings = gio.Settings.newFull(schema, null, null);
    cached_settings = settings;
    return settings;
}

pub fn getLastPage() []const u8 {
    const settings = getSettings() orelse return "welcome";
    const page = gio.Settings.getString(settings, "last-page");
    return std.mem.sliceTo(page, 0);
}

pub fn setLastPage(page: [*:0]const u8) void {
    const settings = getSettings() orelse return;
    _ = gio.Settings.setString(settings, "last-page", page);
}
