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

    const title = gtk.Label.new("Documentation");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, title), "title-1");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, title));

    const desc = gtk.Label.new("Guides and references for Devario OS.");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, desc));

    const site_btn = gtk.Button.newWithLabel("Website");
    _ = gtk.Button.signals.clicked.connect(site_btn, ?*anyopaque, &openSite, null, .{});
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, site_btn));

    const aur_btn = gtk.Button.newWithLabel("AUR Mirror");
    _ = gtk.Button.signals.clicked.connect(aur_btn, ?*anyopaque, &openAurMirror, null, .{});
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, aur_btn));

    return gobject.ext.as(gtk.Widget, page);
}

fn openSite(_: *gtk.Button, _: ?*anyopaque) callconv(.c) void {
    spawn.openUrl("https://www.seafoam-labs.org/");
}

fn openAurMirror(_: *gtk.Button, _: ?*anyopaque) callconv(.c) void {
    spawn.openUrl("https://atoll.seafoam-labs.org/");
}
