const std = @import("std");
const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const gobject = bindings.gobject;
const settings = @import("settings.zig");
const spawn = @import("spawn.zig");

const patreon_url = "https://www.patreon.com/SeafoamLabs";

const welcome = @import("pages/welcome.zig");
const software = @import("pages/software.zig");
const gaming = @import("pages/gaming.zig");
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
        _ = gtk.Stack.addTitled(stack, gaming.build(), "gaming", "Gaming");
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

        const support = gtk.Button.newWithLabel("Support");
        gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, support), "flat");
        gtk.Widget.setMarginStart(gobject.ext.as(gtk.Widget, support), 8);
        gtk.Widget.setMarginEnd(gobject.ext.as(gtk.Widget, support), 6);
        gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, support), 6);
        gtk.Widget.setMarginBottom(gobject.ext.as(gtk.Widget, support), 6);
        gtk.Widget.setTooltipText(gobject.ext.as(gtk.Widget, support), "Support us on Patreon");
        _ = gtk.Button.signals.clicked.connect(support, ?*anyopaque, &openPatreon, null, .{});

        // One panel for the whole column: the StackSidebar paints its own
        // `.sidebar` background and border, which would stop above the button
        // and leave it outside the panel.
        gtk.Widget.removeCssClass(gobject.ext.as(gtk.Widget, sidebar), "sidebar");
        if (gtk.Widget.getFirstChild(gobject.ext.as(gtk.Widget, sidebar))) |child| {
            gtk.Widget.removeCssClass(child, "sidebar");
        }

        const nav = gtk.Box.new(gtk.Orientation.vertical, 0);
        gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, nav), "sidebar");
        gtk.Widget.setVexpand(gobject.ext.as(gtk.Widget, sidebar), 1);
        gtk.Box.append(gobject.ext.as(gtk.Box, nav), gobject.ext.as(gtk.Widget, sidebar));
        gtk.Box.append(gobject.ext.as(gtk.Box, nav), gobject.ext.as(gtk.Widget, support));

        const box = gtk.Box.new(gtk.Orientation.horizontal, 0);
        gtk.Box.append(gobject.ext.as(gtk.Box, box), gobject.ext.as(gtk.Widget, nav));
        gtk.Box.append(gobject.ext.as(gtk.Box, box), gobject.ext.as(gtk.Widget, stack));

        gtk.Window.setChild(gobject.ext.as(gtk.Window, window), gobject.ext.as(gtk.Widget, box));

        return window;
    }

    fn openPatreon(_: *gtk.Button, _: ?*anyopaque) callconv(.c) void {
        spawn.openUrl(patreon_url);
    }

    fn onPageChanged(stack: *gtk.Stack, _: *gobject.ParamSpec, _: ?*anyopaque) callconv(.c) void {
        const name = gtk.Stack.getVisibleChildName(stack) orelse return;
        settings.setLastPage(name);
    }
};
