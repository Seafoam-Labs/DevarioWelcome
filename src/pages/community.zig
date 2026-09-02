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

    const title = gtk.Label.new("Community");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, title), "title-1");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, title));

    const desc = gtk.Label.new("Join the Seafoam Labs community.");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, desc));

    const fluxer_btn = gtk.Button.newWithLabel("Fluxer");
    _ = gtk.Button.signals.clicked.connect(fluxer_btn, ?*anyopaque, &openFluxer, null, .{});
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, fluxer_btn));

    const github_btn = gtk.Button.newWithLabel("GitHub");
    _ = gtk.Button.signals.clicked.connect(github_btn, ?*anyopaque, &openGithub, null, .{});
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, github_btn));

    return gobject.ext.as(gtk.Widget, page);
}

fn openFluxer(_: *gtk.Button, _: ?*anyopaque) callconv(.c) void {
    spawn.openUrl("https://fluxer.gg/ML39pObM");
}

fn openGithub(_: *gtk.Button, _: ?*anyopaque) callconv(.c) void {
    spawn.openUrl("https://github.com/Seafoam-Labs");
}
