const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const heap = std.heap;
const math = std.math;
const time = std.time;
const json = std.json;

const zlua = @import("zlua");
const glfw = @import("glfw");
const zigimg = @import("zigimg");

const tools = @import("tools.zig");
const render_manager = @import("render_manager.zig");
const scene_manager = @import("scene_manager.zig");
const objects = @import("objects.zig");
const vectors = @import("vectors.zig");

const chive_funcs = [_]zlua.FnReg{
    .{ .name = "Setup", .func = zlua.wrap(setup) },
    .{ .name = "CreateScene", .func = zlua.wrap(createScene) },
    .{ .name = "SetScene", .func = zlua.wrap(setScene) },
    .{ .name = "CreateSurface", .func = zlua.wrap(createSurface) },
    .{ .name = "CreateTexture", .func = zlua.wrap(createTexture) },
    .{ .name = "LoadTextureAtlas", .func = zlua.wrap(loadTextureAtlas) },
    .{ .name = "CreateCamera", .func = zlua.wrap(createCamera) },
    .{ .name = "SetCamera", .func = zlua.wrap(setCamera) },
};

const push_idx = -2;
const stack_top_idx = -1;

var allocator: mem.Allocator = undefined;
var renderer: render_manager.Renderer = undefined;
var scenes: std.ArrayList(scene_manager.Scene) = undefined;
var cameras: std.ArrayList(objects.Camera) = undefined;

var fps: i32 = 1;
var fps_milli: i32 = 1;
var current_scene: u32 = 0;
var current_camera: u32 = 0;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    scenes = .init(allocator);
    defer scenes.deinit();
    cameras = .init(allocator);
    defer cameras.deinit();

    defer renderer.deinit();

    defer {
        for (scenes.items) |*scene| {
            scene.deinit();
        }
    }

    const lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();

    lua.newLib(&chive_funcs);
    lua.setGlobal("chive");

    const script = try tools.path_from_binaryZ(allocator, "scripts/main.lua");
    defer allocator.free(script);

    lua.doFile(script) catch |err| {
        std.debug.print("{any}", .{err});
        return err;
    };

    try start(lua);

    // const atlas_path = try tools.path_from_binary(allocator, "test.png");
    // defer allocator.free(atlas_path);
    // var atlas_2_image = try zigimg.Image.fromFilePath(allocator, atlas_path);
    // defer atlas_2_image.deinit();
    // try atlas_2_image.convert(.rgba32);
    // try atlas_2_image.flipVertically();
    // const atlas_2 = atlas_2_image.rawBytes();

    var last_time = time.milliTimestamp();

    // var last_mouse_x: f32 = 0.0;
    // var last_mouse_y: f32 = 0.0;

    // var locked = false;
    // var was_escape_presed = false;

    while (!renderer.window.shouldClose()) {
        const time_stamp = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(time_stamp - last_time)) / 1000.0;
        try tick(lua, delta_time);

        if (time_stamp - last_time >= fps_milli) {
            last_time = time_stamp;
            renderer.render_scene(&cameras.items[current_camera], scenes.items[current_scene]);
            try update(lua, delta_time);
        }
        renderer.update();
        // const mouse_x = @as(f32, @floatCast(renderer.window.getCursorPos().xpos));
        // const mouse_y = @as(f32, @floatCast(renderer.window.getCursorPos().ypos));

        // var velocity: vectors.Vec3 = .zero;

        // if (locked) {
        //     camera.increaseRotation(.{ .x = (sensitivity * delta_time * -(mouse_y - last_mouse_y)) / @as(f32, @floatFromInt(renderer.height)), .y = (sensitivity * delta_time * (mouse_x - last_mouse_x)) / @as(f32, @floatFromInt(renderer.width)), .z = 0 });
        // }

        // const escape_state = renderer.window.getKey(.escape);
        // if (escape_state == glfw.Action.release and !was_escape_presed) {
        //     locked = !locked;
        //     if (locked) {
        //         renderer.window.setInputModeCursor(.disabled);
        //     } else {
        //         renderer.window.setInputModeCursor(.normal);
        //     }
        // }
        //         was_escape_presed = (escape_state == .release);
        //         if (renderer.window.getKey(glfw.Key.w) == glfw.Action.press) {
        //             velocity.add(.{ .x = math.sin(camera.rotation.y), .y = 0, .z = math.cos(camera.rotation.y) });
        //         }
        //         if (renderer.window.getKey(glfw.Key.a) == glfw.Action.press) {
        //             velocity.add(.{ .x = -math.cos(camera.rotation.y), .y = 0, .z = math.sin(camera.rotation.y) });
        //         }
        //         if (renderer.window.getKey(glfw.Key.s) == glfw.Action.press) {
        //             velocity.subtract(.{ .x = math.sin(camera.rotation.y), .y = 0, .z = math.cos(camera.rotation.y) });
        //         }
        //         if (renderer.window.getKey(glfw.Key.d) == glfw.Action.press) {
        //             velocity.add(.{ .x = math.cos(camera.rotation.y), .y = 0, .z = -math.sin(camera.rotation.y) });
        //         }
        //         if (renderer.window.getKey(glfw.Key.space) == glfw.Action.press) {
        //             velocity.add(vectors.Vec3.up);
        //         }
        //         if (renderer.window.getKey(glfw.Key.left_shift) == glfw.Action.press) {
        //             velocity.subtract(vectors.Vec3.up);
        //         }
        //         if (renderer.window.getKey(glfw.Key.left) == glfw.Action.press) {
        //             camera.increaseRotation(.{ .x = 0, .y = -sensitivity * delta_time, .z = 0 });
        //         }
        //         if (renderer.window.getKey(glfw.Key.up) == glfw.Action.press) {
        //             camera.increaseRotation(.{ .x = sensitivity * delta_time, .y = 0, .z = 0 });
        //         }
        //         if (renderer.window.getKey(glfw.Key.down) == glfw.Action.press) {
        //             camera.increaseRotation(.{ .x = -sensitivity * delta_time, .y = 0, .z = 0 });
        //         }
        //         if (renderer.window.getKey(glfw.Key.right) == glfw.Action.press) {
        //             camera.increaseRotation(.{ .x = 0, .y = sensitivity * delta_time, .z = 0 });
        //         }
        //         if (renderer.window.getKey(glfw.Key.q) == glfw.Action.press) {
        //             camera.increaseRotation(.{ .x = 0, .y = 0, .z = -sensitivity * delta_time });
        //         }
        //         if (renderer.window.getKey(glfw.Key.e) == glfw.Action.press) {
        //             camera.increaseRotation(.{ .x = 0, .y = 0, .z = sensitivity * delta_time });
        //         }

        //         var unit = velocity.unit();
        //         unit.multiply(delta_time * walk_speed);

        //         camera.position.add(unit);

        //         last_mouse_x = mouse_x;
        //         last_mouse_y = mouse_y;

        //         renderer.render_scene(&camera, scene);
    }
}

fn setup(lua: *zlua.Lua) i32 {
    const title = pullString(lua, 1);
    fps = pullInt(lua, 2);
    fps_milli = @divTrunc(1000, fps);
    const width = pullUInt(lua, 3);
    const height = pullUInt(lua, 4);
    const display_method = pullUInt(lua, 5);
    const resolution_width = pullUInt(lua, 6);
    const resolution_height = pullUInt(lua, 7);
    const texture_atlas_size = pullUInt(lua, 8);
    const texture_atlas_count = pullUInt(lua, 9);

    var display_method_enum: render_manager.DisplayMethod = .Windowed;

    switch (display_method) {
        0 => display_method_enum = .Windowed,
        1 => display_method_enum = .FullScreen,
        2 => display_method_enum = .Borderless,
        3 => display_method_enum = .BorderlessWindowed,
        else => display_method_enum = .Windowed,
    }

    renderer = render_manager.Renderer.init(allocator, title, width, height, display_method_enum, resolution_width, resolution_height, texture_atlas_size, texture_atlas_count) catch |err| {
        std.debug.print("Error Creating Renderer: {any}", .{err});
        return 0;
    };
    return 0;
}

fn createScene(lua: *zlua.Lua) i32 {
    const scene = scene_manager.Scene.init(allocator) catch {
        std.log.debug("Out of Memory", .{});
        return 0;
    };
    const scene_id = scenes.items.len;
    scenes.append(scene) catch {
        std.log.debug("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(scene_id));
    return 1;
}

fn setScene(lua: *zlua.Lua) i32 {
    const scene_id = pullUInt(lua, 1);
    current_scene = scene_id;
    return 0;
}

fn createTexture(lua: *zlua.Lua) i32 {
    const atlas_id = pullUInt(lua, 1);
    const uv_min = pullVec2(lua, 2);
    const uv_max = pullVec2(lua, 3);
    const texture_type = pullUInt(lua, 4);
    const flip_u = pullBool(lua, 5);
    const flip_v = pullBool(lua, 6);
    const tint = pullColor(lua, 7);
    const size = pullVec2(lua, 8);

    var texture_type_enum: objects.TextureType = .Stretch;

    switch (texture_type) {
        0 => texture_type_enum = .Stretch,
        1 => texture_type_enum = .Tile,
        else => texture_type_enum = .Stretch,
    }

    const texture: objects.Texture = .{
        .altas_id = atlas_id,
        .uv_min = uv_min,
        .uv_max = uv_max,
        .tex_type = texture_type_enum,
        .flip_u = flip_u,
        .flip_v = flip_v,
        .tint = tint,
        .tex_size = size,
    };

    const texture_id = renderer.add_texture(texture) catch {
        std.log.debug("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(texture_id));
    return 1;
}

fn loadTextureAtlas(lua: *zlua.Lua) i32 {
    const atlas_file = pullString(lua, 1);
    const atlas_folder_path = tools.path_from_binaryZ(allocator, "res/atlas") catch |err| {
        std.debug.print("Error Getting Atlas Path: {any}", .{err});
        return 0;
    };
    defer allocator.free(atlas_folder_path);
    const atlas_path = fs.path.joinZ(allocator, &.{ atlas_folder_path, atlas_file }) catch |err| {
        std.debug.print("Error Joining Atlas Path: {any}", .{err});
        return 0;
    };
    defer allocator.free(atlas_path);

    var atlas_image = zigimg.Image.fromFilePath(allocator, atlas_path) catch |err| {
        std.debug.print("Error Getting Atlas: {any}", .{err});
        return 0;
    };
    defer atlas_image.deinit();
    atlas_image.convert(.rgba32) catch |err| {
        std.debug.print("Error Getting Atlas Bytes: {any}", .{err});
        return 0;
    };
    atlas_image.flipVertically() catch |err| {
        std.debug.print("Error Getting Atlas Bytes: {any}", .{err});
        return 0;
    };
    const atlas = atlas_image.rawBytes();

    const atlas_id = renderer.load_texture_atlas(atlas) catch |err| {
        if (err == error.OutOfTextureAtlasBuffers) {
            std.log.debug("Ran Out of Texture Atlas Storage", .{});
            return 0;
        } else {
            std.log.debug("Out of Memory", .{});
            return 0;
        }
    };

    lua.pushInteger(@intCast(atlas_id));
    return 1;
}

fn createSurface(lua: *zlua.Lua) i32 {
    const scene_id = pullUInt(lua, 1);
    const position = pullVec3(lua, 2);
    const normal = pullVec3(lua, 3);
    const rotation = pullNumber(lua, 4);
    const size = pullVec2(lua, 5);
    const texture_id = pullUInt(lua, 6);

    const surface: objects.Surface = .{
        .position = position,
        .normal = normal,
        .rotation = rotation,
        .size = size,
        .texture_id = texture_id,
    };

    const surface_id = scenes.items[scene_id].addSurface(surface) catch {
        std.log.debug("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(surface_id));
    return 1;
}

fn createCamera(lua: *zlua.Lua) i32 {
    const position = pullVec3(lua, 1);
    const rotation = pullVec3(lua, 2);
    const fov = pullNumber(lua, 3);

    const camera = objects.Camera.init(position, rotation, fov);

    const camera_id = cameras.items.len;
    cameras.append(camera) catch {
        std.debug.print("Out of Memory", .{});
        return 1;
    };

    lua.pushInteger(@intCast(camera_id));
    return 1;
}

fn setCamera(lua: *zlua.Lua) i32 {
    const camera_id = pullUInt(lua, 1);
    current_camera = camera_id;
    return 0;
}

fn start(lua: *zlua.Lua) !void {
    _ = lua.getGlobal("Start") catch unreachable;
    try lua.protectedCall(.{});
}

fn update(lua: *zlua.Lua, delta_time: f32) !void {
    _ = lua.getGlobal("Update") catch unreachable;
    lua.pushNumber(delta_time);
    try lua.protectedCall(.{ .args = 1 });
}

fn tick(lua: *zlua.Lua, delta_time: f32) !void {
    _ = lua.getGlobal("Tick") catch unreachable;
    lua.pushNumber(delta_time);
    try lua.protectedCall(.{ .args = 1 });
}

fn pushVec3(lua: *zlua.Lua, vector: vectors.Vec3) void {
    lua.createTable(0, 3);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
    lua.pushNumber(vector.z);
    lua.setField(push_idx, "z");
}

fn pullVec3(lua: *zlua.Lua, idx: i32) vectors.Vec3 {
    _ = lua.getField(idx, "x");
    const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "y");
    const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "z");
    const z: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    return .{ .x = x, .y = y, .z = z };
}

fn pushVec2(lua: *zlua.Lua, vector: vectors.Vec2) void {
    lua.createTable(0, 2);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
}

fn pullVec2(lua: *zlua.Lua, idx: i32) vectors.Vec2 {
    _ = lua.getField(idx, "x");
    const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "y");
    const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    return .{ .x = x, .y = y };
}

fn pushColor(lua: *zlua.Lua, color: vectors.Color) void {
    lua.createTable(0, 4);
    lua.pushNumber(color.r);
    lua.setField(push_idx, "r");
    lua.pushNumber(color.g);
    lua.setField(push_idx, "g");
    lua.pushNumber(color.b);
    lua.setField(push_idx, "b");
    lua.pushNumber(color.a);
    lua.setField(push_idx, "a");
}

fn pullColor(lua: *zlua.Lua, idx: i32) vectors.Color {
    _ = lua.getField(idx, "r");
    const r: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "g");
    const g: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "b");
    const b: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "a");
    const a: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    return .{ .r = r, .g = g, .b = b, .a = a };
}

fn pullNumber(lua: *zlua.Lua, idx: i32) f32 {
    return @floatCast(lua.toNumber(idx) catch 0.0);
}

fn pullInt(lua: *zlua.Lua, idx: i32) i32 {
    return @intCast(lua.toInteger(idx) catch 0);
}

fn pullUInt(lua: *zlua.Lua, idx: i32) u32 {
    return @intCast(lua.toInteger(idx) catch 0);
}

fn pullBool(lua: *zlua.Lua, idx: i32) bool {
    return lua.toBoolean(idx);
}

fn pullString(lua: *zlua.Lua, idx: i32) [:0]const u8 {
    return lua.toString(idx) catch "";
}
