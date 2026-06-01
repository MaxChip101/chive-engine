const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const heap = std.heap;
const time = std.time;
const log = std.log;

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
    .{ .name = "SetCurrentScene", .func = zlua.wrap(setCurrentScene) },
    .{ .name = "CreateSurface", .func = zlua.wrap(createSurface) },
    .{ .name = "SetSurfacePosition", .func = zlua.wrap(setSurfacePosition) },
    .{ .name = "SetSurfaceNormal", .func = zlua.wrap(setSurfaceNormal) },
    .{ .name = "SetSurfaceRotation", .func = zlua.wrap(setSurfaceRotation) },
    .{ .name = "SetSurfaceSize", .func = zlua.wrap(setSurfaceSize) },
    .{ .name = "SetSurfaceTextureID", .func = zlua.wrap(setSurfaceTextureID) },
    .{ .name = "CreateTexture", .func = zlua.wrap(createTexture) },
    .{ .name = "LoadTextureAtlas", .func = zlua.wrap(loadTextureAtlas) },
    .{ .name = "CreateCamera", .func = zlua.wrap(createCamera) },
    .{ .name = "SetCameraPosition", .func = zlua.wrap(setCameraPosition) },
    .{ .name = "SetCameraRotation", .func = zlua.wrap(setCameraRotation) },
    .{ .name = "SetCameraFov", .func = zlua.wrap(setCameraFov) },
    .{ .name = "SetCurrentCamera", .func = zlua.wrap(setCurrentCamera) },
    .{ .name = "SetMouseState", .func = zlua.wrap(setMouseState) },
    .{ .name = "GetMousePos", .func = zlua.wrap(getMousePos) },
    .{ .name = "GetKeyDown", .func = zlua.wrap(getKeyDown) },
    .{ .name = "GetKeyUp", .func = zlua.wrap(getKeyUp) },
    .{ .name = "GetKeyRepeat", .func = zlua.wrap(getKeyRepeat) },
};

const push_idx = -2;
const stack_top_idx = -1;

var allocator: mem.Allocator = undefined;
var renderer: render_manager.Renderer = undefined;
var setup_called = false;
var scenes: std.ArrayList(scene_manager.Scene) = undefined;
var cameras: std.ArrayList(objects.Camera) = undefined;

var fps: i32 = 1;
var fps_milli: i32 = 1000;
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

    inline for (.{
        .{ "TextureType", objects.TextureType },
        .{ "DisplayMethod", render_manager.DisplayMethod },
    }) |pair| {
        lua.newTable();
        inline for (@typeInfo(pair[1]).@"enum".fields) |field| {
            lua.pushInteger(field.value);
            lua.setField(push_idx, field.name);
        }
        lua.setGlobal(pair[0]);
    }

    lua.newTable();
    inline for (@typeInfo(glfw.Key).@"enum".fields) |field| {
        lua.pushInteger(@intFromEnum(@field(glfw.Key, field.name)));
        lua.setField(push_idx, field.name);
    }
    lua.setGlobal("Key");

    lua.newTable();
    inline for (@typeInfo(vectors.Vec2).@"struct".decls) |decl| {
        const val = @field(vectors.Vec2, decl.name);
        if (@TypeOf(val) == vectors.Vec2) {
            pushVec2(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("Vec2");

    lua.newTable();
    lua.pushFunction(zlua.wrap(vec2Length));
    lua.setField(push_idx, "length");
    lua.pushFunction(zlua.wrap(vec2LengthSquared));
    lua.setField(push_idx, "lengthSquared");
    lua.pushFunction(zlua.wrap(vec2Add));
    lua.setField(push_idx, "add");
    lua.pushFunction(zlua.wrap(vec2Subtract));
    lua.setField(push_idx, "subtract");
    lua.pushFunction(zlua.wrap(vec2Multiply));
    lua.setField(push_idx, "multiply");
    lua.pushFunction(zlua.wrap(vec2Divide));
    lua.setField(push_idx, "divide");
    lua.pushFunction(zlua.wrap(vec2Dot));
    lua.setField(push_idx, "dot");
    lua.pushFunction(zlua.wrap(vec2Cross));
    lua.setField(push_idx, "cross");
    lua.pushFunction(zlua.wrap(vec2Unit));
    lua.setField(push_idx, "unit");
    lua.pushValue(stack_top_idx);
    lua.setField(push_idx, "__index");
    lua.setMetatableRegistry("Vec2");

    lua.newTable();
    inline for (@typeInfo(vectors.Vec3).@"struct".decls) |decl| {
        const val = @field(vectors.Vec3, decl.name);
        if (@TypeOf(val) == vectors.Vec3) {
            pushVec3(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("Vec3");

    lua.newTable();
    lua.pushFunction(zlua.wrap(vec3Length));
    lua.setField(push_idx, "length");
    lua.pushFunction(zlua.wrap(vec3LengthSquared));
    lua.setField(push_idx, "lengthSquared");
    lua.pushFunction(zlua.wrap(vec3Add));
    lua.setField(push_idx, "add");
    lua.pushFunction(zlua.wrap(vec3Subtract));
    lua.setField(push_idx, "subtract");
    lua.pushFunction(zlua.wrap(vec3Multiply));
    lua.setField(push_idx, "multiply");
    lua.pushFunction(zlua.wrap(vec3Divide));
    lua.setField(push_idx, "divide");
    lua.pushFunction(zlua.wrap(vec3Dot));
    lua.setField(push_idx, "dot");
    lua.pushFunction(zlua.wrap(vec3Cross));
    lua.setField(push_idx, "cross");
    lua.pushFunction(zlua.wrap(vec3Unit));
    lua.setField(push_idx, "unit");
    lua.pushValue(stack_top_idx);
    lua.setField(push_idx, "__index");
    lua.setMetatableRegistry("Vec3");

    lua.newTable();
    inline for (@typeInfo(vectors.Color).@"struct".decls) |decl| {
        const val = @field(vectors.Color, decl.name);
        if (@TypeOf(val) == vectors.Color) {
            pushColor(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("Color");

    const script = try tools.path_from_binaryZ(allocator, "scripts/main.lua");
    defer allocator.free(script);

    lua.doFile(script) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        return error.LuaRuntime;
    };

    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return;
    }

    defer renderer.deinit();

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

    setup_called = true;

    const display_method_enum: render_manager.DisplayMethod = @enumFromInt(display_method);

    renderer = render_manager.Renderer.init(
        allocator,
        title,
        width,
        height,
        display_method_enum,
        resolution_width,
        resolution_height,
        texture_atlas_size,
        texture_atlas_count,
    ) catch |err| {
        log.err("Error Creating Renderer: {!}", .{err});
        return 0;
    };
    return 0;
}

fn createScene(lua: *zlua.Lua) i32 {
    const scene = scene_manager.Scene.init(allocator) catch {
        log.err("Out of Memory", .{});
        return 0;
    };
    const scene_id = scenes.items.len;
    scenes.append(scene) catch {
        log.err("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(scene_id));
    return 1;
}

fn setCurrentScene(lua: *zlua.Lua) i32 {
    const scene_id = pullUInt(lua, 1);
    current_scene = scene_id;
    return 0;
}

fn createTexture(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const atlas_id = pullUInt(lua, 1);
    const uv_min = pullVec2(lua, 2);
    const uv_max = pullVec2(lua, 3);
    const texture_type = pullUInt(lua, 4);
    const flip_u = pullBool(lua, 5);
    const flip_v = pullBool(lua, 6);
    const tint = pullColor(lua, 7);
    const size = pullVec2(lua, 8);

    const texture_type_enum: objects.TextureType = @enumFromInt(texture_type);

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
        log.err("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(texture_id));
    return 1;
}

fn loadTextureAtlas(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const atlas_file = pullString(lua, 1);
    const atlas_folder_path = tools.path_from_binaryZ(allocator, "res/atlas") catch |err| {
        log.err("Error Getting Atlas Path: {!}", .{err});
        return 0;
    };
    defer allocator.free(atlas_folder_path);
    const atlas_path = fs.path.joinZ(allocator, &.{ atlas_folder_path, atlas_file }) catch |err| {
        log.err("Error Joining Atlas Path: {!}", .{err});
        return 0;
    };
    defer allocator.free(atlas_path);

    var atlas_image = zigimg.Image.fromFilePath(allocator, atlas_path) catch |err| {
        log.err("Error Getting Atlas: {!}", .{err});
        return 0;
    };
    defer atlas_image.deinit();
    atlas_image.convert(.rgba32) catch |err| {
        log.err("Error Getting Atlas Bytes: {!}", .{err});
        return 0;
    };
    atlas_image.flipVertically() catch |err| {
        log.err("Error Getting Atlas Bytes: {!}", .{err});
        return 0;
    };
    const atlas = atlas_image.rawBytes();

    const atlas_id = renderer.load_texture_atlas(atlas) catch |err| {
        if (err == error.OutOfTextureAtlasBuffers) {
            log.err("Ran Out of Texture Atlas Storage", .{});
            return 0;
        } else {
            log.err("Out of Memory", .{});
            return 0;
        }
    };

    lua.pushInteger(@intCast(atlas_id));
    return 1;
}

fn createSurface(lua: *zlua.Lua) i32 {
    const position = pullVec3(lua, 1);
    const normal = pullVec3(lua, 2);
    const rotation = pullNumber(lua, 3);
    const size = pullVec2(lua, 4);
    const texture_id = pullUInt(lua, 5);

    const surface: objects.Surface = .{
        .position = position,
        .normal = normal,
        .rotation = rotation,
        .size = size,
        .texture_id = texture_id,
    };

    const surface_id = scenes.items[current_scene].addSurface(surface) catch {
        log.err("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(surface_id));
    return 1;
}

fn setSurfacePosition(lua: *zlua.Lua) i32 {
    const surface_id = pullUInt(lua, 1);
    const position = pullVec3(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.position = position;

    return 0;
}

fn setSurfaceNormal(lua: *zlua.Lua) i32 {
    const surface_id = pullUInt(lua, 1);
    const normal = pullVec3(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.normal = normal;

    return 0;
}

fn setSurfaceRotation(lua: *zlua.Lua) i32 {
    const surface_id = pullUInt(lua, 1);
    const rotation = pullNumber(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.rotation = rotation;

    return 0;
}

fn setSurfaceSize(lua: *zlua.Lua) i32 {
    const surface_id = pullUInt(lua, 1);
    const size = pullVec2(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.size = size;

    return 0;
}

fn setSurfaceTextureID(lua: *zlua.Lua) i32 {
    const surface_id = pullUInt(lua, 1);
    const texture_id = pullUInt(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.texture_id = texture_id;

    return 0;
}

fn createCamera(lua: *zlua.Lua) i32 {
    const position = pullVec3(lua, 1);
    const rotation = pullVec3(lua, 2);
    const fov = pullNumber(lua, 3);

    const camera = objects.Camera.init(position, rotation, fov);

    const camera_id = cameras.items.len;
    cameras.append(camera) catch {
        log.err("Out of Memory", .{});
        return 1;
    };

    lua.pushInteger(@intCast(camera_id));
    return 1;
}

fn setCameraPosition(lua: *zlua.Lua) i32 {
    const camera_id = pullUInt(lua, 1);
    const position = pullVec3(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.*.position = position;

    return 0;
}

fn setCameraRotation(lua: *zlua.Lua) i32 {
    const camera_id = pullUInt(lua, 1);
    const rotation = pullVec3(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.setRotation(rotation);
    return 0;
}

fn setCameraFov(lua: *zlua.Lua) i32 {
    const camera_id = pullUInt(lua, 1);
    const fov = pullNumber(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.setFov(fov);
    return 0;
}

fn setCurrentCamera(lua: *zlua.Lua) i32 {
    const camera_id = pullUInt(lua, 1);
    current_camera = camera_id;
    return 0;
}

fn getKeyDown(lua: *zlua.Lua) i32 {
    const key = pullUInt(lua, 1);
    const state = renderer.window.getKey(@enumFromInt(key)) == glfw.Action.press;
    lua.pushBoolean(state);
    return 1;
}

fn getKeyUp(lua: *zlua.Lua) i32 {
    const key = pullUInt(lua, 1);
    const state = renderer.window.getKey(@enumFromInt(key)) == glfw.Action.release;
    lua.pushBoolean(state);
    return 1;
}

fn getKeyRepeat(lua: *zlua.Lua) i32 {
    const key = pullUInt(lua, 1);
    const state = renderer.window.getKey(@enumFromInt(key)) == glfw.Action.repeat;
    lua.pushBoolean(state);
    return 1;
}

fn setMouseState(lua: *zlua.Lua) i32 {
    const state = pullUInt(lua, 1);
    const state_enum: glfw.Window.InputModeCursor = @enumFromInt(state);

    renderer.window.setInputModeCursor(state_enum);
    return 0;
}

fn getMousePos(lua: *zlua.Lua) i32 {
    const x = @as(f32, @floatCast(renderer.window.getCursorPos().xpos));
    const y = @as(f32, @floatCast(renderer.window.getCursorPos().ypos));

    pushVec2(lua, .{ .x = x, .y = y });
    return 1;
}

fn update(lua: *zlua.Lua, delta_time: f32) !void {
    _ = lua.getGlobal("Update") catch unreachable;
    lua.pushNumber(delta_time);
    lua.protectedCall(.{ .args = 1 }) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        return error.LuaRuntime;
    };
}

fn tick(lua: *zlua.Lua, delta_time: f32) !void {
    _ = lua.getGlobal("Tick") catch unreachable;
    lua.pushNumber(delta_time);
    lua.protectedCall(.{ .args = 1 }) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        return error.LuaRuntime;
    };
}

fn pushVec3(lua: *zlua.Lua, vector: vectors.Vec3) void {
    lua.createTable(0, 3);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
    lua.pushNumber(vector.z);
    lua.setField(push_idx, "z");
    _ = lua.getMetatableRegistry("Vec3");
    lua.setMetatable(push_idx);
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
    _ = lua.getMetatableRegistry("Vec2");
    lua.setMetatable(push_idx);
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

fn vec2Length(lua: *zlua.Lua) i32 {
    const vector = pullVec2(lua, 1);
    lua.pushNumber(vector.length());
    return 1;
}

fn vec2LengthSquared(lua: *zlua.Lua) i32 {
    const vector = pullVec2(lua, 1);
    lua.pushNumber(vector.length_squared());
    return 1;
}

fn vec2Add(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    vector1.add(vector2);
    pushVec2(lua, vector1);
    return 1;
}

fn vec2Subtract(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    vector1.subtract(vector2);
    pushVec2(lua, vector1);
    return 1;
}

fn vec2Multiply(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.multiply(scalar);
    pushVec2(lua, vector);
    return 1;
}

fn vec2Divide(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.divide(scalar);
    pushVec2(lua, vector);
    return 1;
}

fn vec2Dot(lua: *zlua.Lua) i32 {
    const vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    lua.pushNumber(vector1.dot(vector2));
    return 1;
}

fn vec2Cross(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    lua.pushNumber(vector1.cross(vector2));
    return 1;
}

fn vec2Unit(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    pushVec2(lua, vector.unit());
    return 1;
}

fn vec3Length(lua: *zlua.Lua) i32 {
    const vector = pullVec3(lua, 1);
    lua.pushNumber(vector.length());
    return 1;
}

fn vec3LengthSquared(lua: *zlua.Lua) i32 {
    const vector = pullVec3(lua, 1);
    lua.pushNumber(vector.length_squared());
    return 1;
}

fn vec3Add(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    vector1.add(vector2);
    pushVec3(lua, vector1);
    return 1;
}

fn vec3Subtract(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    vector1.subtract(vector2);
    pushVec3(lua, vector1);
    return 1;
}

fn vec3Multiply(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.multiply(scalar);
    pushVec3(lua, vector);
    return 1;
}

fn vec3Divide(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.divide(scalar);
    pushVec3(lua, vector);
    return 1;
}

fn vec3Dot(lua: *zlua.Lua) i32 {
    const vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    lua.pushNumber(vector1.dot(vector2));
    return 1;
}

fn vec3Cross(lua: *zlua.Lua) i32 {
    const vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    pushVec3(lua, vector1.cross(vector2));
    return 1;
}

fn vec3Unit(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    pushVec3(lua, vector.unit());
    return 1;
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
