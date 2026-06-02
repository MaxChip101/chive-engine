const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });

    const glfw_dep = b.dependency("zig_glfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zgl = b.dependency("zgl", .{
        .target = target,
        .optimize = optimize,
    });

    const zigimg = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "chive_engine",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // if (target.result.os.tag == .windows) {
    //     exe.subsystem = .Windows;
    // }

    exe.root_module.addImport("zgl", zgl.module("zgl"));
    exe.root_module.addImport("glfw", glfw_dep.module("glfw"));
    exe.root_module.addImport("zlua", lua_dep.module("zlua"));
    exe.root_module.addImport("zigimg", zigimg.module("zigimg"));

    const gen = b.addExecutable(.{
        .name = "gen",
        .root_source_file = b.path("gen.zig"),
        .target = target,
        .optimize = .Debug,
    });

    gen.root_module.addImport("glfw", glfw_dep.module("glfw"));
    gen.root_module.addImport("types", b.createModule(.{
        .root_source_file = b.path("src/gen_types.zig"),
    }));
    gen.root_module.addImport("tools", b.createModule(.{
        .root_source_file = b.path("src/tools.zig"),
    }));

    const run_gen = b.addRunArtifact(gen);
    run_gen.addArg("scripts/chive.d.lua");
    exe.step.dependOn(&run_gen.step);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
