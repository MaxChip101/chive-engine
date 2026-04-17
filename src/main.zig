const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const math = std.math;
const time = std.time;

const zlua = @import("zlua");
const game = @import("game.zig");
const renderer = @import("renderer.zig");
const world = @import("world.zig");
const objects = @import("objects.zig");
const vectors = @import("vectors.zig");
const glfw = @import("glfw");

const screen_width = 800;
const screen_height = 600;

var camera: objects.Camera = undefined;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const fps_milli: i64 = @divTrunc(1000, 120);

    var renderer_struct: renderer.Renderer = try .init(allocator, screen_width, screen_height, "mod game");
    defer renderer_struct.deinit();

    var game_struct: game.Game = try .init(allocator);
    defer game_struct.deinit();

    var world_struct: world.World = try .init(allocator);
    defer world_struct.deinit();

    camera = .init(vectors.Vec3.create(0, 0, 0), vectors.Vec3.create(0, 0, 0), .{ .w = 0, .x = 0, .y = 0, .z = 0 }, 90, renderer_struct);

    try world_struct.addWall("wall1", .{ .line = .{ .start = .create(-4, 0, -2), .end = .create(4, 0, -2) }, .height = 2, .material = .{ .color = .create(255, 255, 0, 255) } });
    try world_struct.addWall("wall2", .{ .line = .{ .start = .create(-4, 0, 2), .end = .create(4, 0, 2) }, .height = 2, .material = .{ .color = .create(0, 255, 255, 255) } });
    try world_struct.addWall("pannel1", .{ .line = .{ .start = .create(-2, 0, -1), .end = .create(-2, 0, 1) }, .height = 1, .material = .{ .color = .create(255, 0, 255, 100) } });
    try world_struct.addWall("pannel2", .{ .line = .{ .start = .create(2, 0, 1), .end = .create(2, 2, -1) }, .height = 1, .material = .{ .color = .create(40, 255, 40, 255) } });

    const script_path = try game_struct.path_from_binaryZ("../test.lua");

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();
    lua.doFile(script_path) catch |err| {
        std.debug.print("{any}", .{err});
    };

    var last_time = time.milliTimestamp();

    const walk_speed = 3.0;

    const sensitivity = 100.0;

    while (!renderer_struct.window.shouldClose()) {
        const time_stamp = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(time_stamp - last_time)) / 1000.0;

        if (time_stamp - last_time >= fps_milli) {
            last_time = time_stamp;

            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.w) == glfw.Action.press) {
                camera.position.z += walk_speed * math.sin(camera.rad_rotation.y) * delta_time;
                camera.position.x += walk_speed * math.cos(camera.rad_rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.a) == glfw.Action.press) {
                camera.position.z += walk_speed * math.cos(camera.rad_rotation.y) * delta_time;
                camera.position.x += -walk_speed * math.sin(camera.rad_rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.s) == glfw.Action.press) {
                camera.position.z += -walk_speed * math.sin(camera.rad_rotation.y) * delta_time;
                camera.position.x += -walk_speed * math.cos(camera.rad_rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.d) == glfw.Action.press) {
                camera.position.z += -walk_speed * math.cos(camera.rad_rotation.y) * delta_time;
                camera.position.x += walk_speed * math.sin(camera.rad_rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.left) == glfw.Action.press) {
                camera.rotation.y += sensitivity * delta_time;
                camera.update_rotation();
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.right) == glfw.Action.press) {
                camera.rotation.y -= sensitivity * delta_time;
                camera.update_rotation();
            }

            //renderer_struct.drawCamera(camera, world_struct);
            renderer_struct.render();
        }

        renderer_struct.update();
    }
}
