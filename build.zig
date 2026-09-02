const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gobject = b.dependency("gobject", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("DevarioWelcome", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("glib2", gobject.module("glib2"));
    mod.addImport("gobject2", gobject.module("gobject2"));
    mod.addImport("gio2", gobject.module("gio2"));
    mod.addImport("gtk4", gobject.module("gtk4"));
    mod.addImport("gdk4", gobject.module("gdk4"));

    const exe = b.addExecutable(.{
        .name = "DevarioWelcome",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "DevarioWelcome", .module = mod },
            },
        }),
    });
    exe.root_module.link_libc = true;
    exe.root_module.linkSystemLibrary("gtk4", .{});

    b.installArtifact(exe);

    // Compile GSettings schema
    const schemas_dir = b.fmt("{s}/share/glib-2.0/schemas", .{b.install_path});
    const mkdir_schemas = b.addSystemCommand(&.{ "mkdir", "-p", schemas_dir });
    const compile_schemas = b.addSystemCommand(&.{"glib-compile-schemas"});
    compile_schemas.addDirectoryArg(b.path("data"));
    compile_schemas.addArg("--targetdir");
    compile_schemas.addArg(schemas_dir);
    compile_schemas.addFileInput(b.path("data/com.devario.welcome.gschema.xml"));
    compile_schemas.step.dependOn(&mkdir_schemas.step);
    b.getInstallStep().dependOn(&compile_schemas.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.setEnvironmentVariable("GSETTINGS_SCHEMA_DIR", b.fmt("{s}/share/glib-2.0/schemas", .{b.install_path}));
    if (b.args) |args| run_cmd.addArgs(args);

    const mod_tests = b.addTest(.{ .root_module = mod });
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(mod_tests).step);
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
