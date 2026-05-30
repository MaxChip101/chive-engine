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
const render = @import("render.zig");
const scripting = @import("scripting.zig");
const scenes = @import("scenes.zig");
const objects = @import("objects.zig");
const vectors = @import("vectors.zig");

const chive_funcs = [_]zlua.FnReg{
    .{ .name = "InitChive", .func = zlua.wrap(initChive) },
    .{ .name = "CreateScene", .func = zlua.wrap(createScene) },
    .{ .name = "CreateSurface", .func = zlua.wrap(createSurface) },
    .{ .name = "CreateTexture", .func = zlua.wrap(createTexture) },
    .{ .name = "LoadTextureAtlas", .func = zlua.wrap(loadTextureAtlas) },
    .{ .name = "CreateCamera", .func = zlua.wrap(createCamera) },
};

const push_idx = -2;
const stack_top_idx = -1;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    const script: scripting.ScriptManager = try .init(allocator);
    try script.start();
    defer script.deinit();

    // const atlas_path = try tools.path_from_binary(allocator, "test.png");
    // defer allocator.free(atlas_path);
    // var atlas_2_image = try zigimg.Image.fromFilePath(allocator, atlas_path);
    // defer atlas_2_image.deinit();
    // try atlas_2_image.convert(.rgba32);
    // try atlas_2_image.flipVertically();
    // const atlas_2 = atlas_2_image.rawBytes();

    //const fps_milli: i64 = @divTrunc(1000, settings.frame_rate);

    var last_time = time.milliTimestamp();

    // var last_mouse_x: f32 = 0.0;
    // var last_mouse_y: f32 = 0.0;

    // var locked = false;
    // var was_escape_presed = false;

    while (!renderer.window.shouldClose()) {
        const time_stamp = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(time_stamp - last_time)) / 1000.0;
        try script.tick(delta_time);

        if (time_stamp - last_time >= fps_milli) {
            last_time = time_stamp;
            try script.update(delta_time);
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

        //     renderer.update();
    }
}

fn createScene() i32 {
    const scene = scenes.Scene.init(allocator);
    const scene_id = self.scene_list.items.len;
    self.scene_list.append(scene) catch |err| {
        if (err == error.OutOfMemory) {
            std.log.debug("Out of Memory", .{});
            return;
        }
    };

    lua.pushInteger(scene_id);
    return 1;
}

fn createTexture() i32 {
    // texture

    const scene = scenes.Scene.init(allocator);
    const scene_id = self.scene_list.items.len;
    self.scene_list.append(scene) catch |err| {
        if (err == error.OutOfMemory) {
            std.log.debug("Out of Memory", .{});
            return 1;
        }
    };

    lua.pushInteger(scene_id);
    return 1;
}

fn loadTextureAtlas() i32 {
    // texture
    const scene = scenes.Scene.init(allocator);
    const scene_id = self.scene_list.items.len;
    self.scene_list.append(scene) catch |err| {
        if (err == error.OutOfMemory) {
            std.log.debug("Out of Memory", .{});
            return 1;
        }
    };

    lua.pushInteger(scene_id);
    return 1;
}

fn createSurface() i32 {
    const scene_id: u32 = pullInt(1);
    const position = pullVec3(2);
    const normal = pullVec3(3);
    const rotation = pullNumber(4);
    const size = pullVec2(5);
    const texture_id: u32 = pullInt(6);

    const surface: objects.Surface = .{
        .position = position,
        .normal = normal,
        .rotation = rotation,
        .size = size,
        .texture_id = texture_id,
    };

    const surface_id = scene_list.items[scene_id].addSurface(surface) catch |err| {
        if (err == error.OutOfMemory) {
            std.debug.print("Out of Memory", .{});
            return 1;
        }
    };

    lua.pushInteger(surface_id);
    return 1;
}

fn createCamera(self: Self) i32 {
    const position = pullVec3(1);
    const rotation = pullVec3(2);
    const fov = pullNumber(3);

    const camera = objects.Camera.init(position, rotation, fov);

    const camera_id = self.cameras.items.len;
    self.cameras.append(camera) catch {
        std.debug.print("Out of Memory", .{});
        return 1;
    };

    lua.pushInteger(camera_id);
    return 1;
}

fn start() !void {
    _ = lua.getGlobal("Start") catch unreachable;
    try lua.protectedCall(.{});
}

fn update(delta_time: f32) !void {
    _ = lua.getGlobal("Update") catch unreachable;
    lua.pushNumber(delta_time);
    try lua.protectedCall(.{ .args = 1 });
}

fn tick(delta_time: f32) !void {
    _ = lua.getGlobal("Tick") catch unreachable;
    lua.pushNumber(delta_time);
    try lua.protectedCall(.{ .args = 1 });
}

fn pushVec3(vector: vectors.Vec3) void {
    lua.createTable(0, 3);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
    lua.pushNumber(vector.z);
    lua.setField(push_idx, "z");
}

fn pullVec3(idx: i32) vectors.Vec3 {
    lua.getField(idx, "x");
    const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    lua.getField(idx, "y");
    const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    lua.getField(idx, "z");
    const z: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    return .{ .x = x, .y = y, .z = z };
}

fn pushVec2(vector: vectors.Vec2) void {
    lua.createTable(0, 2);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
}

fn pullVec2(idx: i32) vectors.Vec2 {
    lua.getField(idx, "x");
    const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    lua.getField(idx, "y");
    const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    return .{ .x = x, .y = y };
}

fn pullNumber(idx: i32) f32 {
    return @floatCast(lua.toNumber(idx) catch 0.0);
}

fn pullInt(idx: i32) u32 {
    return @intCast(lua.toInteger(idx) catch 0);
}

fn pullString(idx: i32) [:0]const u8 {
    return lua.toString(idx) catch 0;
}
