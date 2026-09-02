const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const gobject = bindings.gobject;

pub fn build() *gtk.Widget {
    const page = gtk.Box.new(gtk.Orientation.vertical, 12);
    gtk.Widget.setHexpand(gobject.ext.as(gtk.Widget, page), 1);
    gtk.Widget.setVexpand(gobject.ext.as(gtk.Widget, page), 1);
    gtk.Widget.setHalign(gobject.ext.as(gtk.Widget, page), gtk.Align.center);
    gtk.Widget.setValign(gobject.ext.as(gtk.Widget, page), gtk.Align.center);

    const title = gtk.Label.new("Welcome to Devario");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, title), "title-1");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, title));

    const subtitle = gtk.Label.new("Your system is ready. Explore the tools below to get started.");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, subtitle), "body");
    gtk.Box.append(gobject.ext.as(gtk.Box, page), gobject.ext.as(gtk.Widget, subtitle));

    return gobject.ext.as(gtk.Widget, page);
}
