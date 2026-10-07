const std = @import("std");
const bindings = @import("DevarioWelcome");
const gtk = bindings.gtk;
const glib = bindings.glib;
const gobject = bindings.gobject;
const shelly = @import("../shelly.zig");

const catalog_url = "https://www.seafoam-labs.org/gaming.json";

const alloc = std.heap.c_allocator;

const Entry = struct {
    name: []const u8 = "",
    pkg: []const u8 = "",
    description: []const u8 = "",
};

const Catalog = struct {
    packages: []const Entry = &.{},
};

const Card = struct {
    page: *Page,
    name: []const u8,
    pkg: []const u8,
    button: *gtk.Button,
};

const Install = struct {
    page: *Page,
    card: *Card,
    failure: ?[:0]u8 = null,
};

const LoadResult = struct {
    page: *Page,
    arena: *std.heap.ArenaAllocator,
    entries: []const Entry,
    installed: []const bool,
};

const Page = struct {
    list: *gtk.Box,
    revealer: *gtk.Revealer,
    spinner: *gtk.Spinner,
    status: *gtk.Label,

    arena: ?*std.heap.ArenaAllocator = null,

    mutex: std.atomic.Mutex = .unlocked,
    queue: std.ArrayListUnmanaged(*Install) = .empty,
    running: bool = false,

    fn lock(self: *Page) void {
        while (!self.mutex.tryLock()) std.atomic.spinLoopHint();
    }

    fn unlock(self: *Page) void {
        self.mutex.unlock();
    }

    fn busy(self: *Page) bool {
        self.lock();
        defer self.unlock();
        return self.running;
    }
};

pub fn build() *gtk.Widget {
    const root = gtk.Box.new(gtk.Orientation.vertical, 0);
    gtk.Widget.setHexpand(gobject.ext.as(gtk.Widget, root), 1);
    gtk.Widget.setVexpand(gobject.ext.as(gtk.Widget, root), 1);

    const page = alloc.create(Page) catch return gobject.ext.as(gtk.Widget, root);

    const scrolled = gtk.ScrolledWindow.new();
    gtk.Widget.setHexpand(gobject.ext.as(gtk.Widget, scrolled), 1);
    gtk.Widget.setVexpand(gobject.ext.as(gtk.Widget, scrolled), 1);

    const list = gtk.Box.new(gtk.Orientation.vertical, 12);
    gtk.Widget.setMarginStart(gobject.ext.as(gtk.Widget, list), 12);
    gtk.Widget.setMarginEnd(gobject.ext.as(gtk.Widget, list), 12);
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, list), 12);
    gtk.Widget.setMarginBottom(gobject.ext.as(gtk.Widget, list), 12);
    gtk.ScrolledWindow.setChild(scrolled, gobject.ext.as(gtk.Widget, list));

    const revealer = gtk.Revealer.new();
    gtk.Revealer.setTransitionType(revealer, .slide_up);

    const banner = gtk.Box.new(gtk.Orientation.horizontal, 8);
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, banner), "osd");
    gtk.Widget.setMarginStart(gobject.ext.as(gtk.Widget, banner), 12);
    gtk.Widget.setMarginEnd(gobject.ext.as(gtk.Widget, banner), 12);
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, banner), 8);
    gtk.Widget.setMarginBottom(gobject.ext.as(gtk.Widget, banner), 8);

    const spinner = gtk.Spinner.new();
    gtk.Widget.setSizeRequest(gobject.ext.as(gtk.Widget, spinner), 16, 16);
    gtk.Box.append(banner, gobject.ext.as(gtk.Widget, spinner));

    const status = gtk.Label.new("");
    gtk.Label.setWrap(status, 1);
    gtk.Widget.setHexpand(gobject.ext.as(gtk.Widget, status), 1);
    gtk.Label.setXalign(status, 0);
    gtk.Box.append(banner, gobject.ext.as(gtk.Widget, status));

    gtk.Revealer.setChild(revealer, gobject.ext.as(gtk.Widget, banner));

    gtk.Box.append(root, gobject.ext.as(gtk.Widget, scrolled));
    gtk.Box.append(root, gobject.ext.as(gtk.Widget, revealer));

    page.* = .{
        .list = list,
        .revealer = revealer,
        .spinner = spinner,
        .status = status,
    };

    loadCatalog(page);

    return gobject.ext.as(gtk.Widget, root);
}

fn loadCatalog(page: *Page) void {
    showLoading(page);
    const thread = std.Thread.spawn(.{}, loadWorker, .{page}) catch {
        showError(page);
        return;
    };
    thread.detach();
}

fn loadWorker(ctx: ?*anyopaque) void {
    const page: *Page = @ptrCast(@alignCast(ctx));

    const arena = alloc.create(std.heap.ArenaAllocator) catch {
        _ = glib.idleAdd(&showErrorIdle, page);
        return;
    };
    arena.* = .init(alloc);

    var threaded: std.Io.Threaded = .init(alloc, .{});
    defer threaded.deinit();

    const a = arena.allocator();

    const body = fetchJson(a, threaded.io()) catch {
        abandon(arena);
        _ = glib.idleAdd(&showErrorIdle, page);
        return;
    };

    const catalog = std.json.parseFromSliceLeaky(Catalog, a, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch {
        abandon(arena);
        _ = glib.idleAdd(&showErrorIdle, page);
        return;
    };

    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    var installed: std.ArrayListUnmanaged(bool) = .empty;
    const client = shelly.Client{ .alloc = a, .io = threaded.io() };

    for (catalog.packages) |entry| {
        if (!isPackageName(entry.pkg)) continue;
        entries.append(a, entry) catch break;
        installed.append(a, client.isInstalled(entry.pkg)) catch break;
    }

    const result = alloc.create(LoadResult) catch {
        abandon(arena);
        _ = glib.idleAdd(&showErrorIdle, page);
        return;
    };
    result.* = .{
        .page = page,
        .arena = arena,
        .entries = entries.items,
        .installed = installed.items,
    };
    _ = glib.idleAdd(&applyCatalog, result);
}

const max_catalog_bytes = 128 * 1024;

fn fetchJson(a: std.mem.Allocator, io: std.Io) ![]u8 {
    var client: std.http.Client = .{ .allocator = a, .io = io };
    defer client.deinit();

    const buf = try a.alloc(u8, max_catalog_bytes);
    var writer = std.Io.Writer.fixed(buf);

    const result = client.fetch(.{
        .location = .{ .url = catalog_url },
        .response_writer = &writer,
    }) catch return error.FetchFailed;

    if (result.status != .ok) return error.FetchFailed;
    return a.dupe(u8, writer.buffered());
}

fn abandon(arena: *std.heap.ArenaAllocator) void {
    arena.deinit();
    alloc.destroy(arena);
}

fn applyCatalog(data: ?*anyopaque) callconv(.c) c_int {
    const result: *LoadResult = @ptrCast(@alignCast(data));
    const page = result.page;
    defer alloc.destroy(result);

    if (page.arena) |old| abandon(old);
    page.arena = result.arena;

    clearList(page);
    for (result.entries, result.installed) |entry, is_installed| {
        addCard(page, result.arena.allocator(), entry, is_installed);
    }
    return 0;
}

fn showErrorIdle(data: ?*anyopaque) callconv(.c) c_int {
    const page: *Page = @ptrCast(@alignCast(data));
    showError(page);
    return 0;
}

fn addCard(page: *Page, a: std.mem.Allocator, entry: Entry, is_installed: bool) void {
    const card = a.create(Card) catch return;
    const name_text = a.dupeZ(u8, entry.name) catch return;
    const description_text = a.dupeZ(u8, entry.description) catch return;

    card.* = .{
        .page = page,
        .name = entry.name,
        .pkg = entry.pkg,
        .button = undefined,
    };

    const box = gtk.Box.new(gtk.Orientation.horizontal, 12);
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, box), "card");

    const inner = gtk.Box.new(gtk.Orientation.vertical, 2);
    gtk.Widget.setHexpand(gobject.ext.as(gtk.Widget, inner), 1);
    gtk.Widget.setMarginStart(gobject.ext.as(gtk.Widget, inner), 12);
    gtk.Widget.setMarginEnd(gobject.ext.as(gtk.Widget, inner), 12);
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, inner), 12);
    gtk.Widget.setMarginBottom(gobject.ext.as(gtk.Widget, inner), 12);

    const name = gtk.Label.new(name_text);
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, name), "heading");
    gtk.Label.setXalign(name, 0);
    gtk.Box.append(inner, gobject.ext.as(gtk.Widget, name));

    const description = gtk.Label.new(description_text);
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, description), "dim-label");
    gtk.Label.setWrap(description, 1);
    gtk.Label.setXalign(description, 0);
    gtk.Box.append(inner, gobject.ext.as(gtk.Widget, description));

    const button = gtk.Button.newWithLabel(if (is_installed) "Installed" else "Install");
    gtk.Widget.setValign(gobject.ext.as(gtk.Widget, button), gtk.Align.center);
    gtk.Widget.setMarginEnd(gobject.ext.as(gtk.Widget, button), 12);
    if (is_installed) {
        gtk.Widget.setSensitive(gobject.ext.as(gtk.Widget, button), 0);
    } else {
        _ = gtk.Button.signals.clicked.connect(button, *Card, &onInstall, card, .{});
    }
    card.button = button;

    gtk.Box.append(box, gobject.ext.as(gtk.Widget, inner));
    gtk.Box.append(box, gobject.ext.as(gtk.Widget, button));
    gtk.Box.append(page.list, gobject.ext.as(gtk.Widget, box));
}

fn onInstall(_: *gtk.Button, card: *Card) callconv(.c) void {
    const page = card.page;
    const install = alloc.create(Install) catch return;
    install.* = .{ .page = page, .card = card };

    gtk.Button.setLabel(card.button, "Queued");
    gtk.Widget.setSensitive(gobject.ext.as(gtk.Widget, card.button), 0);

    page.lock();
    const queued = page.queue.append(alloc, install) catch {
        page.unlock();
        resetButton(card);
        alloc.destroy(install);
        return;
    };
    _ = queued;

    if (!page.running) {
        const thread = std.Thread.spawn(.{}, drain, .{page}) catch {
            _ = page.queue.pop();
            page.unlock();
            resetButton(card);
            alloc.destroy(install);
            return;
        };
        page.running = true;
        thread.detach();
    }
    page.unlock();
}

fn resetButton(card: *Card) void {
    gtk.Button.setLabel(card.button, "Install");
    gtk.Widget.setSensitive(gobject.ext.as(gtk.Widget, card.button), 1);
}

fn drain(ctx: ?*anyopaque) void {
    const page: *Page = @ptrCast(@alignCast(ctx));

    var threaded: std.Io.Threaded = .init(alloc, .{});
    defer threaded.deinit();

    while (true) {
        page.lock();
        if (page.queue.items.len == 0) {
            page.running = false;
            page.unlock();
            return;
        }
        const install = page.queue.orderedRemove(0);
        page.unlock();

        _ = glib.idleAdd(&beginInstall, install);
        runInstall(install, threaded.io());
        _ = glib.idleAdd(&finishInstall, install);
    }
}

fn runInstall(install: *Install, io: std.Io) void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const client = shelly.Client{ .alloc = arena.allocator(), .io = io };
    const failure = client.install(install.card.pkg) catch return;

    if (failure) |message| {
        defer arena.allocator().free(message);
        install.failure = alloc.dupeZ(u8, message) catch null;
    }
}

fn beginInstall(data: ?*anyopaque) callconv(.c) c_int {
    const install: *Install = @ptrCast(@alignCast(data));
    const page = install.page;

    var buf: [160]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, "Installing {s}…", .{install.card.name}) catch return 0;

    gtk.Label.setText(page.status, text);
    gtk.Spinner.start(page.spinner);
    gtk.Revealer.setRevealChild(page.revealer, 1);
    return 0;
}

fn finishInstall(data: ?*anyopaque) callconv(.c) c_int {
    const install: *Install = @ptrCast(@alignCast(data));
    defer {
        if (install.failure) |failure| alloc.free(failure);
        alloc.destroy(install);
    }

    const page = install.page;

    if (install.failure) |failure| {
        var buf: [512]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buf, "{s}: {s}", .{ install.card.name, failure }) catch
            "The install failed";
        gtk.Label.setText(page.status, text);
        gtk.Spinner.stop(page.spinner);
        gtk.Revealer.setRevealChild(page.revealer, 1);
        resetButton(install.card);
        return 0;
    }

    gtk.Button.setLabel(install.card.button, "Installed");
    if (!page.busy()) {
        gtk.Spinner.stop(page.spinner);
        gtk.Revealer.setRevealChild(page.revealer, 0);
    }
    return 0;
}

fn clearList(page: *Page) void {
    while (gtk.Widget.getFirstChild(gobject.ext.as(gtk.Widget, page.list))) |child| {
        gtk.Box.remove(page.list, child);
    }
}

fn showLoading(page: *Page) void {
    clearList(page);
    const label = gtk.Label.new("Loading…");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, label), "dim-label");
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, label), 24);
    gtk.Box.append(page.list, gobject.ext.as(gtk.Widget, label));
}

fn showError(page: *Page) void {
    clearList(page);

    const heading = gtk.Label.new("This page could not be loaded");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, heading), "title-3");
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, heading), 48);
    gtk.Box.append(page.list, gobject.ext.as(gtk.Widget, heading));

    const body = gtk.Label.new("Devario Welcome could not fetch the gaming catalog. Check your connection and try again.");
    gtk.Widget.addCssClass(gobject.ext.as(gtk.Widget, body), "dim-label");
    gtk.Label.setWrap(body, 1);
    gtk.Label.setJustify(body, .center);
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, body), 8);
    gtk.Box.append(page.list, gobject.ext.as(gtk.Widget, body));

    const retry = gtk.Button.newWithLabel("Try again");
    gtk.Widget.setHalign(gobject.ext.as(gtk.Widget, retry), gtk.Align.center);
    gtk.Widget.setMarginTop(gobject.ext.as(gtk.Widget, retry), 16);
    _ = gtk.Button.signals.clicked.connect(retry, *Page, &onRetry, page, .{});
    gtk.Box.append(page.list, gobject.ext.as(gtk.Widget, retry));
}

fn onRetry(_: *gtk.Button, page: *Page) callconv(.c) void {
    loadCatalog(page);
}

fn isPackageName(name: []const u8) bool {
    if (name.len == 0 or name.len > 64) return false;
    for (name) |ch| {
        switch (ch) {
            'a'...'z', 'A'...'Z', '0'...'9', '@', '.', '_', '+', '-' => {},
            else => return false,
        }
    }
    return true;
}
