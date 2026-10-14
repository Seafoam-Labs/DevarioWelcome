const std = @import("std");

pub const Package = struct {
    Name: []const u8 = "",
};

const frame_prefix = "[JSON]";
const frame_suffix = "[/JSON]";

const CliError = struct {
    @"$kind": []const u8 = "",
    ErrorMessage: []const u8 = "",
    Level: []const u8 = "",
};

const Raw = struct {
    stdout: []u8,
    ok: bool,
};

pub const Client = struct {
    alloc: std.mem.Allocator,
    io: std.Io,

    pub fn isInstalled(self: Client, name: []const u8) bool {
        const raw = self.run(&.{ "-Ssi", name }, false) catch return false;
        defer self.alloc.free(raw.stdout);
        if (!raw.ok) return false;

        const parsed = decodeFirst([]Package, self.alloc, raw.stdout) catch return false;
        defer parsed.deinit();

        for (parsed.value) |pkg| {
            if (std.mem.eql(u8, pkg.Name, name)) return true;
        }
        return false;
    }

    pub fn install(self: Client, name: []const u8) !?[]u8 {
        const raw = try self.run(&.{ "install", "standard", name, "--no-confirm" }, true);
        if (raw.ok) {
            self.alloc.free(raw.stdout);
            return null;
        }

        const detail = failureMessage(self.alloc, raw.stdout) catch null;
        self.alloc.free(raw.stdout);
        return detail orelse
            try self.alloc.dupe(u8, "The install failed and Shelly returned no error details.");
    }

    fn run(self: Client, args: []const []const u8, privileged: bool) !Raw {
        var argv: std.ArrayListUnmanaged([]const u8) = .empty;
        defer argv.deinit(self.alloc);

        if (privileged) try argv.append(self.alloc, "pkexec");
        try argv.append(self.alloc, "shelly");
        try argv.appendSlice(self.alloc, args);
        try argv.append(self.alloc, "--ui-mode");

        const result = std.process.run(self.alloc, self.io, .{ .argv = argv.items }) catch
            return error.CommandFailed;
        defer self.alloc.free(result.stderr);

        const failed = result.term != .exited or result.term.exited != 0;
        return .{ .stdout = result.stdout, .ok = !failed };
    }
};

fn decodeFirst(comptime T: type, alloc: std.mem.Allocator, output: []const u8) !std.json.Parsed(T) {
    const options = std.json.ParseOptions{ .ignore_unknown_fields = true, .allocate = .alloc_always };
    var pos: usize = 0;

    while (nextFrame(output, &pos)) |payload| {
        const json = decodeBase64(alloc, payload) catch continue;
        defer alloc.free(json);
        if (std.mem.indexOf(u8, json, "\"$kind\"") != null) continue;
        return std.json.parseFromSlice(T, alloc, json, options) catch continue;
    }

    return error.NoFrame;
}

fn failureMessage(alloc: std.mem.Allocator, output: []const u8) !?[]u8 {
    var pos: usize = 0;

    while (nextFrame(output, &pos)) |payload| {
        const json = decodeBase64(alloc, payload) catch continue;
        defer alloc.free(json);

        const parsed = std.json.parseFromSlice(CliError, alloc, json, .{ .ignore_unknown_fields = true }) catch continue;
        defer parsed.deinit();

        if (std.mem.eql(u8, parsed.value.@"$kind", "alpm.error") and
            parsed.value.ErrorMessage.len > 0)
            return try alloc.dupe(u8, parsed.value.ErrorMessage);
    }

    return null;
}

fn nextFrame(output: []const u8, pos: *usize) ?[]const u8 {
    const start = std.mem.indexOfPos(u8, output, pos.*, frame_prefix) orelse return null;
    const payload_start = start + frame_prefix.len;
    const end = std.mem.indexOfPos(u8, output, payload_start, frame_suffix) orelse return null;
    pos.* = end + frame_suffix.len;
    return output[payload_start..end];
}

fn decodeBase64(alloc: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.Decoder;
    const size = try decoder.calcSizeForSlice(encoded);
    const out = try alloc.alloc(u8, size);
    errdefer alloc.free(out);
    try decoder.decode(out, encoded);
    return out;
}
