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

    camera = .init(vectors.Vec3{ .x = 0, .y = 0, .z = 0 }, vectors.Vec3{ .x = 0, .y = -90, .z = 0 }, 90, screen_width);

    _ = try world_struct.addWall(.{ .start = .{ .x = -4, .y = 3, .z = 2 }, .end = .{ .x = 4, .y = 0, .z = 2 }, .height = 1.0, .texture_id = 0 });
    _ = try world_struct.addWall(.{ .start = .{ .x = -4, .y = 0, .z = -2 }, .end = .{ .x = 4, .y = 0, .z = -2 }, .height = 1.0, .texture_id = 0 });

    const script_path = try game_struct.path_from_binaryZ("../test.lua");

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();
    // lua.doFile(script_path) catch |err| {
    //     std.debug.print("{any}", .{err});
    // };
    lua.doFile(script_path) catch |err| {
        std.debug.print("{any}", .{err});
    };

    var last_time = time.milliTimestamp();

    const walk_speed = 3.0;

    const sensitivity = 50.0;

    var last_mouse_x: f32 = 0.0;
    var last_mouse_y: f32 = 0.0;

    var locked = false;
    var was_escape_presed = false;

    while (!renderer_struct.window.shouldClose()) {
        const time_stamp = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(time_stamp - last_time)) / 1000.0;

        if (time_stamp - last_time >= fps_milli) {
            last_time = time_stamp;
            const mouse_x = @as(f32, @floatCast(renderer_struct.window.getCursorPos().xpos));
            const mouse_y = @as(f32, @floatCast(renderer_struct.window.getCursorPos().ypos));

            if (locked) {
                camera.increaseRotation(.{ .x = sensitivity * delta_time * -(mouse_y - last_mouse_y), .y = sensitivity * delta_time * (mouse_x - last_mouse_x), .z = 0 });
            }

            const escape_state = renderer_struct.window.getKey(.escape);
            if (escape_state == glfw.Action.release and !was_escape_presed) {
                locked = !locked;
                if (locked) {
                    renderer_struct.window.setInputModeCursor(.disabled);
                } else {
                    renderer_struct.window.setInputModeCursor(.normal);
                }
            }
            was_escape_presed = (escape_state == .release);
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.w) == glfw.Action.press) {
                camera.position.z += walk_speed * math.sin(camera.rotation.y) * delta_time;
                camera.position.x += walk_speed * math.cos(camera.rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.a) == glfw.Action.press) {
                camera.position.z += walk_speed * math.cos(camera.rotation.y) * delta_time;
                camera.position.x += -walk_speed * math.sin(camera.rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.s) == glfw.Action.press) {
                camera.position.z += -walk_speed * math.sin(camera.rotation.y) * delta_time;
                camera.position.x += -walk_speed * math.cos(camera.rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.d) == glfw.Action.press) {
                camera.position.z += -walk_speed * math.cos(camera.rotation.y) * delta_time;
                camera.position.x += walk_speed * math.sin(camera.rotation.y) * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.space) == glfw.Action.press) {
                camera.position.y += walk_speed * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.left_shift) == glfw.Action.press) {
                camera.position.y -= walk_speed * delta_time;
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.left) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = 0, .y = -sensitivity * delta_time, .z = 0 });
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.up) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = sensitivity * delta_time, .y = 0, .z = 0 });
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.down) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = -sensitivity * delta_time, .y = 0, .z = 0 });
            }
            if (glfw.Window.getKey(renderer_struct.window, glfw.Key.right) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = 0, .y = sensitivity * delta_time, .z = 0 });
            }

            last_mouse_x = mouse_x;
            last_mouse_y = mouse_y;

            //renderer_struct.window.setCursorPos(0, 0);

            //renderer_struct.drawCamera(camera, world_struct);
            try renderer_struct.render(&camera, world_struct);
        }

        renderer_struct.update();
    }
}
