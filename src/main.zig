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
    .{ .name = "setup", .func = zlua.wrap(setup) },
    .{ .name = "setFps", .func = zlua.wrap(setFps) },
    .{ .name = "setMousePos", .func = zlua.wrap(setMousePos) },
    .{ .name = "setWindowSize", .func = zlua.wrap(setWindowSize) },
    .{ .name = "getWindowSize", .func = zlua.wrap(getWindowSize) },
    .{ .name = "setTitle", .func = zlua.wrap(setTitle) },
    .{ .name = "createScene", .func = zlua.wrap(createScene) },
    .{ .name = "setCurrentScene", .func = zlua.wrap(setCurrentScene) },
    .{ .name = "createSurface", .func = zlua.wrap(createSurface) },
    .{ .name = "setSurfacePosition", .func = zlua.wrap(setSurfacePosition) },
    .{ .name = "setSurfaceNormal", .func = zlua.wrap(setSurfaceNormal) },
    .{ .name = "setSurfaceRotation", .func = zlua.wrap(setSurfaceRotation) },
    .{ .name = "setSurfaceSize", .func = zlua.wrap(setSurfaceSize) },
    .{ .name = "setSurfaceTextureID", .func = zlua.wrap(setSurfaceTextureID) },
    .{ .name = "createTexture", .func = zlua.wrap(createTexture) },
    .{ .name = "loadTextureAtlas", .func = zlua.wrap(loadTextureAtlas) },
    .{ .name = "createCamera", .func = zlua.wrap(createCamera) },
    .{ .name = "setCameraPosition", .func = zlua.wrap(setCameraPosition) },
    .{ .name = "setCameraRotation", .func = zlua.wrap(setCameraRotation) },
    .{ .name = "setCameraRadRotation", .func = zlua.wrap(setCameraRadRotation) },
    .{ .name = "setCameraFov", .func = zlua.wrap(setCameraFov) },
    .{ .name = "setCurrentCamera", .func = zlua.wrap(setCurrentCamera) },
    .{ .name = "setMouseState", .func = zlua.wrap(setMouseState) },
    .{ .name = "getMousePos", .func = zlua.wrap(getMousePos) },
    .{ .name = "getKeyDown", .func = zlua.wrap(getKeyDown) },
    .{ .name = "getKeyUp", .func = zlua.wrap(getKeyUp) },
    .{ .name = "getKeyRepeat", .func = zlua.wrap(getKeyRepeat) },
};

const vec3_funcs = [_]zlua.FnReg{
    .{ .name = "add", .func = zlua.wrap(vec3Add) },
    .{ .name = "subtract", .func = zlua.wrap(vec3Subtract) },
    .{ .name = "multiply", .func = zlua.wrap(vec3Multiply) },
    .{ .name = "divide", .func = zlua.wrap(vec3Divide) },
    .{ .name = "length", .func = zlua.wrap(vec3Length) },
    .{ .name = "lengthSquared", .func = zlua.wrap(vec3LengthSquared) },
    .{ .name = "dot", .func = zlua.wrap(vec3Dot) },
    .{ .name = "cross", .func = zlua.wrap(vec3Cross) },
    .{ .name = "unit", .func = zlua.wrap(vec3Unit) },
};

const vec2_funcs = [_]zlua.FnReg{
    .{ .name = "add", .func = zlua.wrap(vec2Add) },
    .{ .name = "subtract", .func = zlua.wrap(vec2Subtract) },
    .{ .name = "multiply", .func = zlua.wrap(vec2Multiply) },
    .{ .name = "divide", .func = zlua.wrap(vec2Divide) },
    .{ .name = "length", .func = zlua.wrap(vec2Length) },
    .{ .name = "lengthSquared", .func = zlua.wrap(vec2LengthSquared) },
    .{ .name = "dot", .func = zlua.wrap(vec2Dot) },
    .{ .name = "cross", .func = zlua.wrap(vec2Cross) },
    .{ .name = "unit", .func = zlua.wrap(vec2Unit) },
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

    lua.newTable();
    const enums_idx = lua.getTop();

    inline for (.{
        .{ "TextureType", objects.TextureType },
        .{ "DisplayMethod", render_manager.DisplayMethod },
    }) |pair| {
        lua.newTable();
        inline for (@typeInfo(pair[1]).@"enum".fields) |field| {
            lua.pushInteger(field.value);
            lua.setField(push_idx, field.name);
        }
        lua.setField(enums_idx, pair[0]);
    }

    lua.newTable();
    inline for (@typeInfo(glfw.Window.InputModeCursor).@"enum".fields) |field| {
        lua.pushInteger(@intFromEnum(@field(glfw.Window.InputModeCursor, field.name)));
        lua.setField(push_idx, field.name);
    }
    lua.setField(enums_idx, "MouseState");

    lua.newTable();
    inline for (@typeInfo(glfw.Key).@"enum".fields) |field| {
        lua.pushInteger(@intFromEnum(@field(glfw.Key, field.name)));
        lua.setField(push_idx, field.name);
    }
    lua.setField(enums_idx, "Key");
    lua.setGlobal("enum");

    lua.newLib(&vec2_funcs);
    inline for (@typeInfo(vectors.Vec2).@"struct".decls) |decl| {
        const val = @field(vectors.Vec2, decl.name);
        if (@TypeOf(val) == vectors.Vec2) {
            pushVec2(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("vec2");

    lua.newLib(&vec3_funcs);
    inline for (@typeInfo(vectors.Vec3).@"struct".decls) |decl| {
        const val = @field(vectors.Vec3, decl.name);
        if (@TypeOf(val) == vectors.Vec3) {
            pushVec3(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("vec3");

    lua.newTable();
    inline for (@typeInfo(vectors.Color).@"struct".decls) |decl| {
        const val = @field(vectors.Color, decl.name);
        if (@TypeOf(val) == vectors.Color) {
            pushColor(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("color");

    const script = try tools.path_from_binaryZ(allocator, "scripts/main.lua");
    defer allocator.free(script);

    lua.doFile(script) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        if (setup_called) renderer.deinit();
        return error.LuaRuntime;
    };

    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return;
    }

    defer renderer.deinit();

    var last_tick = time.milliTimestamp();

    while (!renderer.window.shouldClose()) {
        const current_tick = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(current_tick - last_tick)) / 1000.0;
        try tick(lua, delta_time);

        if (current_tick - last_tick >= fps_milli) {
            last_tick = current_tick;
            renderer.renderScene(&cameras.items[current_camera], scenes.items[current_scene]);
            try update(lua, delta_time);
        }

        renderer.update();
    }
}

fn setup(lua: *zlua.Lua) i32 {
    const title = pullString(lua, 1);
    const size = pullVec2(lua, 2);
    const display_method = pullUInt(lua, 3);
    const resolution = pullVec2(lua, 4);
    const texture_atlas_size = pullUInt(lua, 5);
    const texture_atlas_count = pullUInt(lua, 6);

    setup_called = true;

    const display_method_enum: render_manager.DisplayMethod = @enumFromInt(display_method);

    renderer = render_manager.Renderer.init(
        allocator,
        title,
        @as(u32, @intFromFloat(size.x)),
        @as(u32, @intFromFloat(size.y)),
        display_method_enum,
        @as(u32, @intFromFloat(resolution.x)),
        @as(u32, @intFromFloat(resolution.y)),
        texture_atlas_size,
        texture_atlas_count,
    ) catch |err| {
        log.err("Error Creating Renderer: {!}", .{err});
        return 0;
    };
    return 0;
}

fn setTitle(lua: *zlua.Lua) i32 {
    const title = pullString(lua, 1);
    renderer.setTitle(title);
    return 0;
}

fn setWindowSize(lua: *zlua.Lua) i32 {
    const size = pullVec2(lua, 1);
    renderer.setSize(size);
    return 0;
}

fn setMousePos(lua: *zlua.Lua) i32 {
    const pos = pullVec2(lua, 1);
    renderer.setCursorPos(pos);
    return 0;
}

fn setFps(lua: *zlua.Lua) i32 {
    fps = pullInt(lua, 1);
    fps_milli = @divTrunc(1000, fps);
    return 0;
}

fn getWindowSize(lua: *zlua.Lua) i32 {
    pushVec2(lua, .{ .x = @floatFromInt(renderer.width), .y = @floatFromInt(renderer.height) });
    return 1;
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

    const texture_id = renderer.addTexture(texture) catch {
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

    const atlas_id = renderer.loadTextureAtlas(atlas) catch |err| {
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

fn setCameraRadRotation(lua: *zlua.Lua) i32 {
    const camera_id = pullUInt(lua, 1);
    const rotation = pullVec3(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.*.rotation = rotation;
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
    const key = pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const state = renderer.window.getKey(key_enum) == glfw.Action.press;
    lua.pushBoolean(state);
    return 1;
}

fn getKeyUp(lua: *zlua.Lua) i32 {
    const key = pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const state = renderer.window.getKey(key_enum) == glfw.Action.release;
    lua.pushBoolean(state);
    return 1;
}

fn getKeyRepeat(lua: *zlua.Lua) i32 {
    const key = pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const state = renderer.window.getKey(key_enum) == glfw.Action.repeat;
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
    _ = lua.getGlobal("update") catch unreachable;
    lua.pushNumber(delta_time);
    lua.protectedCall(.{ .args = 1 }) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        return error.LuaRuntime;
    };
}

fn tick(lua: *zlua.Lua, delta_time: f32) !void {
    _ = lua.getGlobal("tick") catch unreachable;
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

fn writeVec2(lua: *zlua.Lua, idx: i32, vector: vectors.Vec2) void {
    lua.pushNumber(vector.x);
    lua.setField(idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(idx, "y");
}

fn writeVec3(lua: *zlua.Lua, idx: i32, vector: vectors.Vec3) void {
    lua.pushNumber(vector.x);
    lua.setField(idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(idx, "y");
    lua.pushNumber(vector.z);
    lua.setField(idx, "z");
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
    writeVec2(lua, 1, vector1);
    return 0;
}

fn vec2Subtract(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    vector1.subtract(vector2);
    writeVec2(lua, 1, vector1);
    return 0;
}

fn vec2Multiply(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.multiply(scalar);
    writeVec2(lua, 1, vector);
    return 0;
}

fn vec2Divide(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.divide(scalar);
    writeVec2(lua, 1, vector);
    return 0;
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
    writeVec3(lua, 1, vector1);
    return 0;
}

fn vec3Subtract(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    vector1.subtract(vector2);
    writeVec3(lua, 1, vector1);
    return 0;
}

fn vec3Multiply(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.multiply(scalar);
    writeVec3(lua, 1, vector);
    return 0;
}

fn vec3Divide(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.divide(scalar);
    writeVec3(lua, 1, vector);
    return 0;
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
