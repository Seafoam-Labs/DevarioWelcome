const std = @import("std");
const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const gio = bindings.gio;
const gobject = bindings.gobject;

const MainWindow = @import("window.zig").MainWindow;

pub fn main() void {
    const app = gtk.Application.new("com.devario.welcome", .{});
    defer app.unref();

    _ = gio.Application.signals.activate.connect(app, ?*anyopaque, &activate, null, .{});

    const status = gio.Application.run(gobject.ext.as(gio.Application, app), 0, null);
    std.process.exit(@intCast(status));
}

fn activate(app: *gtk.Application, _: ?*anyopaque) callconv(.c) void {
    const window = MainWindow.new(app);
    gtk.Window.present(gobject.ext.as(gtk.Window, window));
}
