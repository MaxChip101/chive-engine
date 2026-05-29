const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const math = std.math;
const time = std.time;
const json = std.json;

const zlua = @import("zlua");
const glfw = @import("glfw");
const zigimg = @import("zigimg");

const tools = @import("tools.zig");
const rendering_manager = @import("renderer.zig");
const world_manager = @import("world.zig");
const objects = @import("objects.zig");
const vectors = @import("vectors.zig");

var camera: objects.Camera = undefined;

const Settings = struct {
    walkspeed: f32,
    camera_sensitivity: f32,
    fov: f32,
    frame_rate: u32,
    resolution_width: u32,
    resolution_height: u32,
    width: u32,
    height: u32,
    fullscreen: bool,
    texture_atlas_size: usize,
    texture_atlas_count: usize,
};

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    const atlas_path = try tools.path_from_binary(allocator, "test.png");
    defer allocator.free(atlas_path);
    var atlas_2_image = try zigimg.Image.fromFilePath(allocator, atlas_path);
    defer atlas_2_image.deinit();
    try atlas_2_image.convert(.rgba32);
    try atlas_2_image.flipVertically();
    const atlas_2 = atlas_2_image.rawBytes();

    const settings_file = try tools.path_from_binary(allocator, "settings.json");
    defer allocator.free(settings_file);
    const settings_content = try tools.read_file_from_path(allocator, settings_file);
    defer allocator.free(settings_content);
    const settings_json = try json.parseFromSlice(Settings, allocator, settings_content, .{});
    defer settings_json.deinit();
    const settings = settings_json.value;

    const fps_milli: i64 = @divTrunc(1000, settings.frame_rate);

    var world: world_manager.World = try .init(allocator);
    defer world.deinit();

    var display_method: rendering_manager.DisplayMethod = .Windowed;

    if (settings.fullscreen)
        display_method = .FullScreen;

    var renderer: rendering_manager.Renderer = try .init(allocator, "chive engine", settings.width, settings.height, display_method, settings.resolution_width, settings.resolution_height, settings.texture_atlas_size, settings.texture_atlas_count);
    defer renderer.deinit();

    const atlas = try renderer.load_texture_atlas(atlas_2);
    const texture: rendering_manager.Texture = .{ .altas_id = atlas, .tint = vectors.Color.white, .uv_min = .{ .x = 0, .y = 0 }, .uv_max = .{ .x = 1, .y = 1 }, .tex_size = .{ .x = 1, .y = 1 }, .tex_type = .Stretch, .flip_u = false, .flip_v = false };

    const texture_id = try renderer.add_texture(texture);

    camera = .init(vectors.Vec3{ .x = 0, .y = 1.5, .z = 0 }, vectors.Vec3{ .x = 0, .y = 0, .z = 0 }, settings.fov, renderer.width / settings.resolution_width);

    _ = try world.addSurface(.{ .position = .{ .x = 0, .y = 1, .z = 2 }, .normal = .{ .x = 0, .y = 1.0, .z = 0.0 }, .rotation = 0.0, .size = .{ .x = 1, .y = 1 }, .texture_id = texture_id });
    _ = try world.addSurface(.{ .position = .{ .x = 0, .y = 1, .z = 3 }, .normal = .{ .x = 0, .y = 0.0, .z = -1.0 }, .rotation = 0.0, .size = .{ .x = 1, .y = 1 }, .texture_id = texture_id });

    const script_path = try tools.path_from_binaryZ("test.lua");

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();
    lua.doFile(script_path) catch |err| {
        std.debug.print("{any}", .{err});
    };

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

            var velocity: vectors.Vec3 = .zero;

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
                velocity.add(.{ .x = math.sin(camera.rotation.y), .y = 0, .z = math.cos(camera.rotation.y) });
            }
            if (renderer.window.getKey(glfw.Key.a) == glfw.Action.press) {
                velocity.add(.{ .x = -math.cos(camera.rotation.y), .y = 0, .z = math.sin(camera.rotation.y) });
            }
            if (renderer.window.getKey(glfw.Key.s) == glfw.Action.press) {
                velocity.subtract(.{ .x = math.sin(camera.rotation.y), .y = 0, .z = math.cos(camera.rotation.y) });
            }
            if (renderer.window.getKey(glfw.Key.d) == glfw.Action.press) {
                velocity.add(.{ .x = math.cos(camera.rotation.y), .y = 0, .z = -math.sin(camera.rotation.y) });
            }
            if (renderer.window.getKey(glfw.Key.space) == glfw.Action.press) {
                velocity.add(vectors.Vec3.up);
            }
            if (renderer.window.getKey(glfw.Key.left_shift) == glfw.Action.press) {
                velocity.subtract(vectors.Vec3.up);
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
            if (renderer.window.getKey(glfw.Key.q) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = 0, .y = 0, .z = -sensitivity * delta_time });
            }
            if (renderer.window.getKey(glfw.Key.e) == glfw.Action.press) {
                camera.increaseRotation(.{ .x = 0, .y = 0, .z = sensitivity * delta_time });
            }

            var unit = velocity.unit();
            unit.multiply(delta_time * walk_speed);

            camera.position.add(unit);

            last_mouse_x = mouse_x;
            last_mouse_y = mouse_y;

            renderer.render(&camera, world);
        }

        renderer.update();
    }
}
