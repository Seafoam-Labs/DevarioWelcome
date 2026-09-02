const std = @import("std");
const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const gobject = bindings.gobject;
const settings = @import("settings.zig");

const welcome = @import("pages/welcome.zig");
const software = @import("pages/software.zig");
const docs = @import("pages/docs.zig");
const community = @import("pages/community.zig");

pub const MainWindow = struct {
    pub fn new(app: *gtk.Application) *gtk.Window {
        const window = gtk.Window.new();
        gtk.Window.setApplication(window, app);
        gtk.Window.setTitle(window, "Devario Welcome");
        gtk.Window.setDefaultSize(window, 800, 600);

        const stack = gtk.Stack.new();
        gtk.Stack.setTransitionType(stack, gtk.StackTransitionType.slide_left_right);

        const sidebar = gtk.StackSidebar.new();
        gtk.StackSidebar.setStack(sidebar, stack);

        _ = gtk.Stack.addTitled(stack, welcome.build(), "welcome", "Welcome");
        _ = gtk.Stack.addTitled(stack, software.build(), "software", "Software");
        _ = gtk.Stack.addTitled(stack, docs.build(), "docs", "Documentation");
        _ = gtk.Stack.addTitled(stack, community.build(), "community", "Community");

        // Restore last page
        const last_page = settings.getLastPage();
        if (last_page.len > 0) {
            var buf: [64]u8 = undefined;
            const name = std.fmt.bufPrintZ(&buf, "{s}", .{last_page}) catch "welcome";
            gtk.Stack.setVisibleChildName(stack, name);
        }

        // Save page on change
        _ = gobject.Object.signals.notify.connect(
            stack,
            ?*anyopaque,
            &onPageChanged,
            null,
            .{ .detail = "visible-child-name" },
        );

        const box = gtk.Box.new(gtk.Orientation.horizontal, 0);
        gtk.Box.append(gobject.ext.as(gtk.Box, box), gobject.ext.as(gtk.Widget, sidebar));
        gtk.Box.append(gobject.ext.as(gtk.Box, box), gobject.ext.as(gtk.Widget, stack));

        gtk.Window.setChild(gobject.ext.as(gtk.Window, window), gobject.ext.as(gtk.Widget, box));

        return window;
    }

    fn onPageChanged(stack: *gtk.Stack, _: *gobject.ParamSpec, _: ?*anyopaque) callconv(.c) void {
        const name = gtk.Stack.getVisibleChildName(stack) orelse return;
        settings.setLastPage(name);
    }
};
