const std = @import("std");
const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const gio = bindings.gio;
const gobject = bindings.gobject;

pub fn main() void {
    const app = gtk.Application.new("com.devario.welcome", .{});
    defer app.unref();

    _ = gio.Application.signals.activate.connect(app, ?*anyopaque, &activate, null, .{});

    const status = gio.Application.run(gobject.ext.as(gio.Application, app), 0, null);
    std.process.exit(@intCast(status));
}

fn activate(app: *gtk.Application, _: ?*anyopaque) callconv(.c) void {
    const window = gtk.Window.new();
    gtk.Window.setApplication(window, app);
    gtk.Window.setTitle(window, "Devario Welcome");
    gtk.Window.setDefaultSize(window, 400, 300);

    const label = gtk.Label.new("Hello, World!");
    gtk.Window.setChild(gobject.ext.as(gtk.Window, window), gobject.ext.as(gtk.Widget, label));

    gtk.Window.present(gobject.ext.as(gtk.Window, window));
}
