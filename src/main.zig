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
const lua_funcs = @import("lua_funcs.zig");

const chive_funcs = [_]zlua.FnReg{
    .{ .name = "setup", .func = zlua.wrap(setup) },
    .{ .name = "setFps", .func = zlua.wrap(setFps) },
    .{ .name = "setMousePos", .func = zlua.wrap(setMousePos) },
    .{ .name = "setWindowSize", .func = zlua.wrap(setWindowSize) },
    .{ .name = "getWindowSize", .func = zlua.wrap(getWindowSize) },
    .{ .name = "getWindowPos", .func = zlua.wrap(getWindowPos) },
    .{ .name = "setWindowPos", .func = zlua.wrap(setWindowPos) },
    .{ .name = "getFps", .func = zlua.wrap(getFps) },
    .{ .name = "getDisplayMode", .func = zlua.wrap(getDisplayMode) },
    .{ .name = "setResizable", .func = zlua.wrap(setResizable) },
    .{ .name = "setDisplayMode", .func = zlua.wrap(setDisplayMode) },
    .{ .name = "setTitle", .func = zlua.wrap(setTitle) },
    .{ .name = "createScene", .func = zlua.wrap(createScene) },
    .{ .name = "getSceneIDs", .func = zlua.wrap(getSceneIDs) },
    .{ .name = "deleteScene", .func = zlua.wrap(deleteScene) },
    .{ .name = "setCurrentScene", .func = zlua.wrap(setCurrentScene) },
    .{ .name = "getCurrentScene", .func = zlua.wrap(getCurrentScene) },
    .{ .name = "createSurface", .func = zlua.wrap(createSurface) },
    .{ .name = "getSurfaceIDs", .func = zlua.wrap(getSurfaceIDs) },
    .{ .name = "getSurfacePosition", .func = zlua.wrap(getSurfacePosition) },
    .{ .name = "getSurfaceNormal", .func = zlua.wrap(getSurfaceNormal) },
    .{ .name = "getSurfaceRotation", .func = zlua.wrap(getSurfaceRotation) },
    .{ .name = "getSurfaceRadRotation", .func = zlua.wrap(getSurfaceRadRotation) },
    .{ .name = "getSurfaceSize", .func = zlua.wrap(getSurfaceSize) },
    .{ .name = "getSurfaceTextureID", .func = zlua.wrap(getSurfaceTextureID) },
    .{ .name = "setSurfacePosition", .func = zlua.wrap(setSurfacePosition) },
    .{ .name = "setSurfaceNormal", .func = zlua.wrap(setSurfaceNormal) },
    .{ .name = "setSurfaceRotation", .func = zlua.wrap(setSurfaceRotation) },
    .{ .name = "setSurfaceRadRotation", .func = zlua.wrap(setSurfaceRadRotation) },
    .{ .name = "setSurfaceSize", .func = zlua.wrap(setSurfaceSize) },
    .{ .name = "setSurfaceTextureID", .func = zlua.wrap(setSurfaceTextureID) },
    .{ .name = "removeSurface", .func = zlua.wrap(removeSurface) },
    .{ .name = "createTexture", .func = zlua.wrap(createTexture) },
    .{ .name = "removeTexture", .func = zlua.wrap(removeTexture) },
    .{ .name = "getTextureUVMin", .func = zlua.wrap(getTextureUVMin) },
    .{ .name = "getTextureUVMax", .func = zlua.wrap(getTextureUVMax) },
    .{ .name = "getTextureSize", .func = zlua.wrap(getTextureSize) },
    .{ .name = "getTextureTint", .func = zlua.wrap(getTextureTint) },
    .{ .name = "getTextureUFlip", .func = zlua.wrap(getTextureUFlip) },
    .{ .name = "getTextureVFlip", .func = zlua.wrap(getTextureVFlip) },
    .{ .name = "getTextureType", .func = zlua.wrap(getTextureType) },
    .{ .name = "getTextureAtlasID", .func = zlua.wrap(getTextureAtlasID) },
    .{ .name = "setTextureUVMin", .func = zlua.wrap(setTextureUVMin) },
    .{ .name = "setTextureUVMax", .func = zlua.wrap(setTextureUVMax) },
    .{ .name = "setTextureSize", .func = zlua.wrap(setTextureSize) },
    .{ .name = "setTextureTint", .func = zlua.wrap(setTextureTint) },
    .{ .name = "setTextureUFlip", .func = zlua.wrap(setTextureUFlip) },
    .{ .name = "setTextureVFlip", .func = zlua.wrap(setTextureVFlip) },
    .{ .name = "setTextureType", .func = zlua.wrap(setTextureType) },
    .{ .name = "setTextureAtlasID", .func = zlua.wrap(setTextureAtlasID) },
    .{ .name = "loadTextureAtlas", .func = zlua.wrap(loadTextureAtlas) },
    .{ .name = "createCamera", .func = zlua.wrap(createCamera) },
    .{ .name = "getCameraIDs", .func = zlua.wrap(getCameraIDs) },
    .{ .name = "getCameraFov", .func = zlua.wrap(getCameraFov) },
    .{ .name = "getCameraRadFov", .func = zlua.wrap(getCameraRadFov) },
    .{ .name = "getCameraPosition", .func = zlua.wrap(getCameraPosition) },
    .{ .name = "getCameraRotation", .func = zlua.wrap(getCameraRotation) },
    .{ .name = "getCameraRadRotation", .func = zlua.wrap(getCameraRadRotation) },
    .{ .name = "setCameraPosition", .func = zlua.wrap(setCameraPosition) },
    .{ .name = "setCameraRotation", .func = zlua.wrap(setCameraRotation) },
    .{ .name = "setCameraRadRotation", .func = zlua.wrap(setCameraRadRotation) },
    .{ .name = "setCameraRadFov", .func = zlua.wrap(setCameraRadFov) },
    .{ .name = "setCameraFov", .func = zlua.wrap(setCameraFov) },
    .{ .name = "deleteCamera", .func = zlua.wrap(deleteCamera) },
    .{ .name = "setCurrentCamera", .func = zlua.wrap(setCurrentCamera) },
    .{ .name = "getCurrentCamera", .func = zlua.wrap(getCurrentCamera) },
    .{ .name = "setMouseState", .func = zlua.wrap(setMouseState) },
    .{ .name = "getMouseState", .func = zlua.wrap(getMouseState) },
    .{ .name = "getMousePos", .func = zlua.wrap(getMousePos) },
    .{ .name = "getKeyDown", .func = zlua.wrap(getKeyDown) },
    .{ .name = "getKeyUp", .func = zlua.wrap(getKeyUp) },
    .{ .name = "getKeyPressed", .func = zlua.wrap(getKeyPressed) },
    .{ .name = "getKeyReleased", .func = zlua.wrap(getKeyReleased) },
    .{ .name = "getKeyRepeat", .func = zlua.wrap(getKeyRepeat) },
};

const push_idx = -2;
const stack_top_idx = -1;

var allocator: mem.Allocator = undefined;
var renderer: render_manager.Renderer = undefined;
var setup_called = false;
var next_scene_id: u32 = 0;
var next_camera_id: u32 = 0;
var scenes: std.AutoArrayHashMap(u32, scene_manager.Scene) = undefined;
var cameras: std.AutoArrayHashMap(u32, objects.Camera) = undefined;
var keys: std.AutoHashMap(glfw.Key, bool) = undefined;

var fps: i64 = 1;
var fps_ms: i64 = 1000;
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
    keys = .init(allocator);
    defer keys.deinit();

    defer {
        for (scenes.values()) |*scene| {
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
        .{ "DisplayMode", render_manager.DisplayMode },
        .{ "Key", glfw.Key },
        .{ "MouseState", glfw.Window.InputModeCursor },
    }) |pair| {
        lua.newTable();
        inline for (@typeInfo(pair[1]).@"enum".fields) |field| {
            lua.pushInteger(field.value);
            lua.setField(push_idx, field.name);
        }
        lua.setGlobal(pair[0]);
    }

    lua.newLib(&lua_funcs.vec2_funcs);
    inline for (@typeInfo(vectors.Vec2).@"struct".decls) |decl| {
        const val = @field(vectors.Vec2, decl.name);
        if (@TypeOf(val) == vectors.Vec2) {
            lua_funcs.pushVec2(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("vec2");

    lua.newLib(&lua_funcs.vec3_funcs);
    inline for (@typeInfo(vectors.Vec3).@"struct".decls) |decl| {
        const val = @field(vectors.Vec3, decl.name);
        if (@TypeOf(val) == vectors.Vec3) {
            lua_funcs.pushVec3(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("vec3");

    lua.newTable();
    inline for (@typeInfo(vectors.Color).@"struct".decls) |decl| {
        const val = @field(vectors.Color, decl.name);
        if (@TypeOf(val) == vectors.Color) {
            lua_funcs.pushColor(lua, val);
            lua.setField(push_idx, decl.name);
        }
    }
    lua.setGlobal("color");

    const script = try tools.pathFromBinaryZ(allocator, "scripts/main.lua");
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

    var last_time = time.milliTimestamp();

    var accumulator: i64 = 0;

    while (!renderer.window.shouldClose()) {
        const current_time = time.milliTimestamp();
        const delta_time_ms = current_time - last_time;
        const delta_time: f32 = @as(f32, @floatFromInt(delta_time_ms)) / 1000.0;
        last_time = current_time;
        accumulator += delta_time_ms;

        if (delta_time_ms >= fps_ms) {
            try lua_funcs.fixedUpdate(lua, @as(f32, @floatFromInt(fps_ms)) / 1000.0);
            accumulator -= fps_ms;
        }

        try lua_funcs.update(lua, delta_time);

        const scene = scenes.get(current_scene) orelse {
            log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
            continue;
        };

        const camera = cameras.getPtr(current_camera) orelse {
            log.err("Surface With ID: {d} Does Not Exist", .{current_camera});
            continue;
        };

        renderer.renderScene(camera, scene);
        renderer.update();
    }
}

fn setup(lua: *zlua.Lua) i32 {
    if (setup_called) {
        log.warn("Setup Was Already Called", .{});
        return 0;
    }
    const title = lua_funcs.pullString(lua, 1);
    const size = lua_funcs.pullVec2(lua, 2);
    const display_mode = lua_funcs.pullUInt(lua, 3);
    const resolution = lua_funcs.pullVec2(lua, 4);
    const texture_atlas_size = lua_funcs.pullUInt(lua, 5);
    const texture_atlas_count = lua_funcs.pullUInt(lua, 6);

    setup_called = true;

    const display_mode_enum: render_manager.DisplayMode = @enumFromInt(display_mode);

    renderer = render_manager.Renderer.init(
        allocator,
        title,
        @as(u32, @intFromFloat(size.x)),
        @as(u32, @intFromFloat(size.y)),
        display_mode_enum,
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

fn setDisplayMode(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const display_mode = lua_funcs.pullUInt(lua, 1);
    renderer.setDisplayMode(@enumFromInt(display_mode));
    return 0;
}

fn setResizable(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const resizable = lua_funcs.pullBool(lua, 1);
    renderer.setResizable(resizable);
    return 0;
}

fn setTitle(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const title = lua_funcs.pullString(lua, 1);
    renderer.setTitle(title);
    return 0;
}

fn setWindowSize(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const size = lua_funcs.pullVec2(lua, 1);
    renderer.setSize(size);
    return 0;
}

fn setMousePos(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const pos = lua_funcs.pullVec2(lua, 1);
    renderer.setCursorPos(pos);
    return 0;
}

fn setFps(lua: *zlua.Lua) i32 {
    fps = lua_funcs.pullInt(lua, 1);
    fps_ms = @divTrunc(1000, fps);
    return 0;
}

fn getWindowSize(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    lua_funcs.pushVec2(lua, .{ .x = @floatFromInt(renderer.width), .y = @floatFromInt(renderer.height) });
    return 1;
}

fn getFps(lua: *zlua.Lua) i32 {
    lua.pushInteger(fps);
    return 1;
}

fn getDisplayMode(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    lua.pushInteger(@intFromEnum(renderer.display_mode));
    return 1;
}

fn getWindowPos(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const pos = renderer.window.getPos();

    const x: f32 = @floatFromInt(pos.x);
    const y: f32 = @floatFromInt(pos.y);

    lua_funcs.pushVec2(lua, .{ .x = x, .y = y });
    return 1;
}

fn setWindowPos(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const pos = lua_funcs.pullVec2(lua, 1);

    renderer.window.setPos(.{ .x = @intFromFloat(pos.x), .y = @intFromFloat(pos.y) });
    return 0;
}

fn createScene(lua: *zlua.Lua) i32 {
    const scene = scene_manager.Scene.init(allocator) catch {
        log.err("Out of Memory", .{});
        return 0;
    };
    const scene_id = next_scene_id;
    scenes.put(scene_id, scene) catch {
        log.err("Out of Memory", .{});
        return 0;
    };
    next_scene_id += 1;

    lua.pushInteger(@intCast(scene_id));
    return 1;
}

fn getSceneIDs(lua: *zlua.Lua) i32 {
    const scene_ids = scenes.keys();

    var i: i32 = 0;
    for (scene_ids) |id| {
        lua.pushInteger(@intCast(id));
        lua.rawSetIndex(push_idx, i);
        i += 1;
    }

    return 1;
}

fn deleteScene(lua: *zlua.Lua) i32 {
    const scene_id = lua_funcs.pullUInt(lua, 1);
    const successful = scenes.swapRemove(scene_id);

    lua.pushBoolean(successful);

    return 1;
}

fn setCurrentScene(lua: *zlua.Lua) i32 {
    const scene_id = lua_funcs.pullUInt(lua, 1);
    current_scene = scene_id;
    return 0;
}

fn getCurrentScene(lua: *zlua.Lua) i32 {
    lua.pushInteger(current_scene);
    return 1;
}

fn createTexture(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const atlas_id = lua_funcs.pullUInt(lua, 1);
    const uv_min = lua_funcs.pullVec2(lua, 2);
    const uv_max = lua_funcs.pullVec2(lua, 3);
    const texture_type = lua_funcs.pullUInt(lua, 4);
    const flip_u = lua_funcs.pullBool(lua, 5);
    const flip_v = lua_funcs.pullBool(lua, 6);
    const tint = lua_funcs.pullColor(lua, 7);
    const size = lua_funcs.pullVec2(lua, 8);

    const texture_type_enum: objects.TextureType = @enumFromInt(texture_type);

    const texture: objects.Texture = .{
        .atlas_id = atlas_id,
        .uv_min = uv_min,
        .uv_max = uv_max,
        .tex_type = texture_type_enum,
        .flip_u = @intFromBool(flip_u),
        .flip_v = @intFromBool(flip_v),
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

fn getTextureUVMin(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua_funcs.pushVec2(lua, texture.uv_min);

    return 1;
}

fn getTextureUVMax(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua_funcs.pushVec2(lua, texture.uv_max);

    return 1;
}

fn getTextureSize(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua_funcs.pushVec2(lua, texture.tex_size);

    return 1;
}

fn getTextureTint(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua_funcs.pushColor(lua, texture.tint);

    return 1;
}

fn getTextureUFlip(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua.pushBoolean(texture.flip_u != 0);

    return 1;
}

fn getTextureVFlip(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua.pushBoolean(texture.flip_v != 0);

    return 1;
}

fn getTextureType(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua.pushInteger(@intFromEnum(texture.tex_type));

    return 1;
}

fn getTextureAtlasID(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    lua.pushInteger(@intCast(texture.atlas_id));

    return 1;
}

fn setTextureUVMin(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const uv_min = lua_funcs.pullVec2(lua, 2);

    const texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.uv_min = uv_min;

    return 0;
}

fn setTextureUVMax(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const uv_max = lua_funcs.pullVec2(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.uv_max = uv_max;

    return 0;
}

fn setTextureSize(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const size = lua_funcs.pullVec2(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.tex_size = size;

    return 0;
}

fn setTextureTint(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const tint = lua_funcs.pullColor(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.tint = tint;

    return 0;
}

fn setTextureUFlip(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const u_flip = lua_funcs.pullBool(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.flip_u = @intFromBool(u_flip);

    return 0;
}

fn setTextureVFlip(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const v_flip = lua_funcs.pullBool(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.flip_v = @intFromBool(v_flip);

    return 0;
}

fn setTextureType(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const texture_type = lua_funcs.pullUInt(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.tex_type = @enumFromInt(texture_type);

    return 0;
}

fn setTextureAtlasID(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const atlas_id = lua_funcs.pullUInt(lua, 2);

    const texture: *objects.Texture = renderer.texture_objects.getPtr(texture_id) orelse {
        log.err("Texture With ID: {d} Does Not Exist", .{texture_id});
        return 0;
    };

    texture.*.atlas_id = atlas_id;

    return 0;
}

fn removeTexture(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const texture_id = lua_funcs.pullUInt(lua, 1);
    const successful = renderer.removeTexture(texture_id);

    lua.pushBoolean(successful);

    return 1;
}

fn loadTextureAtlas(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const atlas_file = lua_funcs.pullString(lua, 1);
    const atlas_folder_path = tools.pathFromBinaryZ(allocator, "res/atlas") catch |err| {
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

fn getSurfaceIDs(lua: *zlua.Lua) i32 {
    const scene: *scene_manager.Scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface_ids = scene.surfaces.keys();

    var i: i32 = 0;
    for (surface_ids) |id| {
        lua.pushInteger(@intCast(id));
        lua.rawSetIndex(push_idx, i);
        i += 1;
    }

    return 1;
}

fn createSurface(lua: *zlua.Lua) i32 {
    const position = lua_funcs.pullVec3(lua, 1);
    const normal = lua_funcs.pullVec3(lua, 2);
    const rotation = lua_funcs.pullNumber(lua, 3);
    const size = lua_funcs.pullVec2(lua, 4);
    const texture_id = lua_funcs.pullUInt(lua, 5);

    const surface: objects.Surface = .{
        .position = position,
        .normal = normal,
        .rotation = rotation,
        .size = size,
        .texture_id = texture_id,
    };

    const scene: *scene_manager.Scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface_id = scene.addSurface(surface) catch {
        log.err("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(surface_id));
    return 1;
}

fn getSurfacePosition(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene: scene_manager.Scene = scenes.get(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: objects.Surface = scene.surfaces.get(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    lua_funcs.pushVec3(lua, surface.position);

    return 1;
}

fn getSurfaceNormal(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene: scene_manager.Scene = scenes.get(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: objects.Surface = scene.surfaces.get(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    lua_funcs.pushVec3(lua, surface.normal);

    return 1;
}

fn getSurfaceSize(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene: scene_manager.Scene = scenes.get(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: objects.Surface = scene.surfaces.get(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    lua_funcs.pushVec2(lua, surface.size);

    return 1;
}

fn getSurfaceRadRotation(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene: scene_manager.Scene = scenes.get(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: objects.Surface = scene.surfaces.get(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    lua.pushNumber(surface.rotation);

    return 1;
}

fn getSurfaceRotation(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene: scene_manager.Scene = scenes.get(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: objects.Surface = scene.surfaces.get(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    lua.pushNumber(surface.getRotation());

    return 1;
}

fn getSurfaceTextureID(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene: scene_manager.Scene = scenes.get(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: objects.Surface = scene.surfaces.get(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    lua.pushInteger(surface.texture_id);

    return 1;
}

fn setSurfacePosition(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const position = lua_funcs.pullVec3(lua, 2);

    const scene: *scene_manager.Scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: *objects.Surface = scene.surfaces.getPtr(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    surface.*.position = position;

    return 0;
}

fn setSurfaceNormal(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const normal = lua_funcs.pullVec3(lua, 2);

    const scene: *scene_manager.Scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: *objects.Surface = scene.surfaces.getPtr(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    surface.*.normal = normal;

    return 0;
}

fn setSurfaceRotation(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullNumber(lua, 2);

    const scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: *objects.Surface = scene.surfaces.getPtr(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    surface.setRotation(rotation);

    return 0;
}

fn setSurfaceRadRotation(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullNumber(lua, 2);

    const scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: *objects.Surface = scene.surfaces.getPtr(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    surface.*.rotation = rotation;

    return 0;
}

fn setSurfaceSize(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const size = lua_funcs.pullVec2(lua, 2);

    const scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: *objects.Surface = scene.surfaces.getPtr(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    surface.*.size = size;

    return 0;
}

fn setSurfaceTextureID(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const texture_id = lua_funcs.pullUInt(lua, 2);

    const scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const surface: *objects.Surface = scene.surfaces.getPtr(surface_id) orelse {
        log.err("Surface With ID: {d} Does Not Exist", .{surface_id});
        return 0;
    };

    surface.*.texture_id = texture_id;

    return 0;
}

fn removeSurface(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);

    const scene = scenes.getPtr(current_scene) orelse {
        log.err("Scene With ID: {d} Does Not Exist", .{current_scene});
        return 0;
    };

    const successful = scene.removeSurface(surface_id);

    lua.pushBoolean(successful);

    return 1;
}

fn createCamera(lua: *zlua.Lua) i32 {
    const position = lua_funcs.pullVec3(lua, 1);
    const rotation = lua_funcs.pullVec3(lua, 2);
    const fov = lua_funcs.pullNumber(lua, 3);

    const camera = objects.Camera.init(position, rotation, fov);

    const camera_id = next_camera_id;
    cameras.put(camera_id, camera) catch {
        log.err("Out of Memory", .{});
        return 1;
    };
    next_camera_id += 1;

    lua.pushInteger(@intCast(camera_id));
    return 1;
}

fn getCameraIDs(lua: *zlua.Lua) i32 {
    const camera_ids = cameras.keys();

    var i: i32 = 0;
    for (camera_ids) |id| {
        lua.pushInteger(@intCast(id));
        lua.rawSetIndex(push_idx, i);
        i += 1;
    }

    return 1;
}

fn getCameraPosition(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);

    const camera: objects.Camera = cameras.get(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    lua_funcs.pushVec3(lua, camera.position);

    return 1;
}

fn getCameraRadRotation(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);

    const camera: objects.Camera = cameras.get(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    lua_funcs.pushVec3(lua, camera.rotation);

    return 1;
}

fn getCameraRotation(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);

    const camera: objects.Camera = cameras.get(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    lua_funcs.pushVec3(lua, camera.getRotation());

    return 1;
}

fn getCameraFov(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);

    const camera: objects.Camera = cameras.get(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    lua.pushNumber(camera.getFov());

    return 1;
}

fn getCameraRadFov(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);

    const camera: objects.Camera = cameras.get(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    lua.pushNumber(camera.fov);

    return 1;
}

fn setCameraPosition(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const position = lua_funcs.pullVec3(lua, 2);

    const camera = cameras.getPtr(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    camera.*.position = position;

    return 0;
}

fn setCameraRotation(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullVec3(lua, 2);

    const camera: *objects.Camera = cameras.getPtr(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    camera.setRotation(rotation);
    return 0;
}

fn setCameraRadRotation(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullVec3(lua, 2);

    const camera: *objects.Camera = cameras.getPtr(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    camera.*.rotation = rotation;
    return 0;
}

fn setCameraFov(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const fov = lua_funcs.pullNumber(lua, 2);

    const camera: *objects.Camera = cameras.getPtr(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    camera.setFov(fov);
    return 0;
}

fn setCameraRadFov(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const fov = lua_funcs.pullNumber(lua, 2);

    const camera: *objects.Camera = cameras.getPtr(camera_id) orelse {
        log.err("Camera With ID: {d} Does Not Exist", .{camera_id});
        return 0;
    };

    camera.setRadFov(fov);
    return 0;
}

fn deleteCamera(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const successful = cameras.swapRemove(camera_id);

    lua.pushBoolean(successful);

    return 1;
}

fn setCurrentCamera(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    current_camera = camera_id;
    return 0;
}

fn getCurrentCamera(lua: *zlua.Lua) i32 {
    lua.pushInteger(current_camera);
    return 1;
}

fn getKeyDown(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const key = lua_funcs.pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    keys.put(key_enum, true) catch {
        log.err("Out of Memory", .{});
    };
    const state = renderer.window.getKey(key_enum) == glfw.Action.press;
    lua.pushBoolean(state);
    return 1;
}

fn getKeyUp(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const key = lua_funcs.pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    keys.put(key_enum, false) catch {
        log.err("Out of Memory", .{});
    };
    const state = renderer.window.getKey(key_enum) == glfw.Action.release;
    lua.pushBoolean(state);
    return 1;
}

fn getKeyPressed(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const key = lua_funcs.pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const last_state = keys.get(key_enum) orelse false;

    keys.put(key_enum, (renderer.window.getKey(key_enum) == glfw.Action.press)) catch {
        log.err("Out of Memory", .{});
    };

    const state = (renderer.window.getKey(key_enum) == glfw.Action.press and !last_state);
    lua.pushBoolean(state);

    return 1;
}

fn getKeyReleased(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const key = lua_funcs.pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const last_state = keys.get(key_enum) orelse false;

    keys.put(key_enum, (renderer.window.getKey(key_enum) == glfw.Action.press)) catch {
        log.err("Out of Memory", .{});
    };

    const state = (renderer.window.getKey(key_enum) == glfw.Action.release and last_state);
    lua.pushBoolean(state);
    return 1;
}

fn getKeyRepeat(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const key = lua_funcs.pullInt(lua, 1);
    const key_enum = std.meta.intToEnum(glfw.Key, key) catch {
        lua.pushBoolean(false);
        return 1;
    };
    const state = renderer.window.getKey(key_enum) == glfw.Action.repeat;
    lua.pushBoolean(state);
    return 1;
}

fn setMouseState(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const state = lua_funcs.pullUInt(lua, 1);
    const state_enum: glfw.Window.InputModeCursor = @enumFromInt(state);

    renderer.window.setInputModeCursor(state_enum);
    return 0;
}

fn getMouseState(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    lua.pushInteger(@intFromEnum(renderer.window.getInputModeCursor()));
    return 1;
}

fn getMousePos(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }

    const pos = renderer.window.getCursorPos();

    const x = @as(f32, (@floatCast(pos.xpos)));
    const y = @as(f32, @floatCast(pos.ypos));

    lua_funcs.pushVec2(lua, .{ .x = x, .y = y });
    return 1;
}
