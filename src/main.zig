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

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const screen_width = 800;
    const screen_height = 600;

    const fps_milli: i64 = @divTrunc(1000, 120);

    var renderer_struct: renderer.Renderer = try .init(allocator, screen_width, screen_height);
    defer renderer_struct.deinit();

    var game_struct: game.Game = try .init(allocator);
    defer game_struct.deinit();

    var world_struct: world.World = try .init(allocator);
    defer world_struct.deinit();

    var camera = objects.Camera.init(vectors.Vec3.create(0, 0, 0), vectors.Vec3.create(0, 0, 0), .{ .w = 0, .x = 0, .y = 0, .z = 0 }, 60, screen_width);
    try world_struct.addComponent(.{ .wall = .{ .position = vectors.Vec3.create(-10, 0, 2), .scale = vectors.Vec3.create(10, 0, 2), .rotation = .{ .x = 0, .y = 0, .z = 0 }, .orientation = .{ .w = 0, .x = 0, .y = 0, .z = 0 } } });
    try world_struct.addComponent(.{ .wall = .{ .position = vectors.Vec3.create(-10, 0, -2), .scale = vectors.Vec3.create(10, 0, -2), .rotation = .{ .x = 0, .y = 0, .z = 0 }, .orientation = .{ .w = 0, .x = 0, .y = 0, .z = 0 } } });

    const script_path = try game_struct.path_from_binaryZ("../test.lua");

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();
    lua.doFile(script_path) catch |err| {
        std.debug.print("{any}", .{err});
    };

    var last_time = time.milliTimestamp();

    while (!renderer_struct.window.shouldClose()) {
        const time_stamp = time.milliTimestamp();
        if (time_stamp - last_time >= fps_milli) {
            last_time = time_stamp;

            renderer_struct.clear();
            renderer_struct.drawCamera(camera, world_struct);
            renderer_struct.render();
            camera.rotation.y += 0.3;
            camera.update_rotation();

            update();
        }
        renderer_struct.update();
    }
}

fn update() void {}
