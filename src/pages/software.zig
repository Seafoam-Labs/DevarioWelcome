const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const gobject = bindings.gobject;
const spawn = @import("../spawn.zig");

pub fn build() *gtk.Widget {
    const page = gtk.Box.new(gtk.Orientation.vertical, 12);
    gtk.Widget.setHexpand(gobject.ext.as(gtk.Widget, page), 1);
    gtk.Widget.setVexpand(gobject.ext.as(gtk.Widget, page), 1);
    gtk.Widget.setHalign(gobject.ext.as(gtk.Widget, page), gtk.Align.center);
    gtk.Widget.setValign(gobject.ext.as(gtk.Widget, page), gtk.Align.center);

    const title = gtk.Label.new("Software");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, title), "title-1");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, title));

    const desc = gtk.Label.new("Install and manage software on your system.");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, desc));

    const pkg_btn = gtk.Button.newWithLabel("Open Package Manager");
    _ = gtk.Button.signals.clicked.connect(pkg_btn, ?*anyopaque, &launchShelly, null, .{});
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, pkg_btn));

    return gobject.ext.as(gtk.Widget, page);
}

fn launchShelly(_: *gtk.Button, _: ?*anyopaque) callconv(.c) void {
    spawn.launchApp("shelly-ui");
}
