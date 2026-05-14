const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const math = std.math;
const time = std.time;
const json = std.json;

const zlua = @import("zlua");
const glfw = @import("glfw");

const tool_class = @import("tools.zig");
const renderer_class = @import("renderer.zig");
const world_class = @import("world.zig");
const objects = @import("objects.zig");
const vectors = @import("vectors.zig");

var camera: objects.Camera = undefined;

const Settings = struct {
    walkspeed: f32,
    camera_sensitivity: f32,
    fov: f32,
    frame_rate: u32,
    max_walls: u32,
    render_scale: u32,
    width: u32,
    height: u32,
    fullscreen: bool,
};

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const fps_milli: i64 = @divTrunc(1000, 120);

    var tools: tool_class.Tools = try .init(allocator);
    defer tools.deinit();

    const settings_file = try tools.path_from_binary("settings.json");
    const settings_content = try tools.read_file_from_path(settings_file);
    const settings_json = try json.parseFromSlice(Settings, allocator, settings_content, .{});
    const settings = settings_json.value;

    var world_struct: world_class.World = try .init(allocator);
    defer world_struct.deinit();

    var renderer: renderer_class.Renderer = try .init(allocator, settings.width, settings.height, "chive engine", settings.max_walls, settings.render_scale, settings.fullscreen);
    defer renderer.deinit();

    camera = .init(vectors.Vec3{ .x = 0, .y = 0, .z = 0 }, vectors.Vec3{ .x = 0, .y = -90, .z = 0 }, settings.fov, settings.width);

    _ = try world_struct.addWall(.{ .start = .{ .x = -4, .y = 3, .z = 2 }, .end = .{ .x = 4, .y = 0, .z = 2 }, .height = 1.0, .texture_id = 0 });
    _ = try world_struct.addWall(.{ .start = .{ .x = -4, .y = 0, .z = -2 }, .end = .{ .x = 4, .y = 0, .z = -2 }, .height = 1.0, .texture_id = 0 });

    // const script_path = try tools.path_from_binaryZ("test.lua");

    // var lua = try zlua.Lua.init(allocator);
    // defer lua.deinit();
    // lua.openLibs();
    // lua.doFile(script_path) catch |err| {
    //     std.debug.print("{any}", .{err});
    // };

    var last_time = time.milliTimestamp();

    const walk_speed = settings.walkspeed;

    const sensitivity = settings.camera_sensitivity;

    var last_mouse_x: f32 = 0.0;
    var last_mouse_y: f32 = 0.0;

    var locked = false;
    var was_escape_presed = false;

    while (!renderer.window.shouldClose()) {
        const time_stamp = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(time_stamp - last_time)) / 1000.0;

        if (time_stamp - last_time >= fps_milli) {
            last_time = time_stamp;
            const mouse_x = @as(f32, @floatCast(renderer.window.getCursorPos().xpos));
            const mouse_y = @as(f32, @floatCast(renderer.window.getCursorPos().ypos));

            if (locked) {
                camera.increaseRotation(.{ .x = sensitivity * delta_time * -(mouse_y - last_mouse_y), .y = sensitivity * delta_time * (mouse_x - last_mouse_x), .z = 0 });
            }

            const escape_state = renderer.window.getKey(.escape);
            if (escape_state == glfw.Action.release and !was_escape_presed) {
                locked = !locked;
                if (locked) {
                    renderer.window.setInputModeCursor(.disabled);
                } else {
                    renderer.window.setInputModeCursor(.normal);
                }
            }
            was_escape_presed = (escape_state == .release);
            if (renderer.window.getKey(glfw.Key.w) == glfw.Action.press) {
                camera.position.z += walk_speed * math.sin(camera.rotation.y) * delta_time;
                camera.position.x += walk_speed * math.cos(camera.rotation.y) * delta_time;
            }
            if (renderer.window.getKey(glfw.Key.a) == glfw.Action.press) {
                camera.position.z += walk_speed * math.cos(camera.rotation.y) * delta_time;
                camera.position.x += -walk_speed * math.sin(camera.rotation.y) * delta_time;
            }
            if (renderer.window.getKey(glfw.Key.s) == glfw.Action.press) {
                camera.position.z += -walk_speed * math.sin(camera.rotation.y) * delta_time;
                camera.position.x += -walk_speed * math.cos(camera.rotation.y) * delta_time;
            }
            if (renderer.window.getKey(glfw.Key.d) == glfw.Action.press) {
                camera.position.z += -walk_speed * math.cos(camera.rotation.y) * delta_time;
                camera.position.x += walk_speed * math.sin(camera.rotation.y) * delta_time;
            }
            if (renderer.window.getKey(glfw.Key.space) == glfw.Action.press) {
                camera.position.y += walk_speed * delta_time;
            }
            if (renderer.window.getKey(glfw.Key.left_shift) == glfw.Action.press) {
                camera.position.y -= walk_speed * delta_time;
            }
            if (renderer.window.getKey(glfw.Key.left) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = 0, .y = -sensitivity * delta_time, .z = 0 });
            }
            if (renderer.window.getKey(glfw.Key.up) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = sensitivity * delta_time, .y = 0, .z = 0 });
            }
            if (renderer.window.getKey(glfw.Key.down) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = -sensitivity * delta_time, .y = 0, .z = 0 });
            }
            if (renderer.window.getKey(glfw.Key.right) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = 0, .y = sensitivity * delta_time, .z = 0 });
            }

            last_mouse_x = mouse_x;
            last_mouse_y = mouse_y;

            try renderer.render(&camera, world_struct);
        }

        renderer.update();
    }
}
