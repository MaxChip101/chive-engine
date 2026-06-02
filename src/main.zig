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

    var last_tick = time.milliTimestamp();

    while (!renderer.window.shouldClose()) {
        const current_tick = time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(current_tick - last_tick)) / 1000.0;
        try lua_funcs.tick(lua, delta_time);

        if (current_tick - last_tick >= fps_milli) {
            last_tick = current_tick;
            renderer.renderScene(&cameras.items[current_camera], scenes.items[current_scene]);
            try lua_funcs.update(lua, delta_time);
        }

        renderer.update();
    }
}

fn setup(lua: *zlua.Lua) i32 {
    const title = lua_funcs.pullString(lua, 1);
    const size = lua_funcs.pullVec2(lua, 2);
    const display_method = lua_funcs.pullUInt(lua, 3);
    const resolution = lua_funcs.pullVec2(lua, 4);
    const texture_atlas_size = lua_funcs.pullUInt(lua, 5);
    const texture_atlas_count = lua_funcs.pullUInt(lua, 6);

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
    fps_milli = @divTrunc(1000, fps);
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
    const scene_id = lua_funcs.pullUInt(lua, 1);
    current_scene = scene_id;
    return 0;
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

    const surface_id = scenes.items[current_scene].addSurface(surface) catch {
        log.err("Out of Memory", .{});
        return 0;
    };

    lua.pushInteger(@intCast(surface_id));
    return 1;
}

fn setSurfacePosition(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const position = lua_funcs.pullVec3(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.position = position;

    return 0;
}

fn setSurfaceNormal(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const normal = lua_funcs.pullVec3(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.normal = normal;

    return 0;
}

fn setSurfaceRotation(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullNumber(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.rotation = rotation;

    return 0;
}

fn setSurfaceSize(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const size = lua_funcs.pullVec2(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.size = size;

    return 0;
}

fn setSurfaceTextureID(lua: *zlua.Lua) i32 {
    const surface_id = lua_funcs.pullUInt(lua, 1);
    const texture_id = lua_funcs.pullUInt(lua, 2);

    const scene: *scene_manager.Scene = &scenes.items[current_scene];
    const surface: *objects.Surface = &scene.surfaces.items[surface_id];
    surface.*.texture_id = texture_id;

    return 0;
}

fn createCamera(lua: *zlua.Lua) i32 {
    const position = lua_funcs.pullVec3(lua, 1);
    const rotation = lua_funcs.pullVec3(lua, 2);
    const fov = lua_funcs.pullNumber(lua, 3);

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
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const position = lua_funcs.pullVec3(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.*.position = position;

    return 0;
}

fn setCameraRotation(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullVec3(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.setRotation(rotation);
    return 0;
}

fn setCameraRadRotation(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const rotation = lua_funcs.pullVec3(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.*.rotation = rotation;
    return 0;
}

fn setCameraFov(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    const fov = lua_funcs.pullNumber(lua, 2);

    const camera = &cameras.items[camera_id];

    camera.setFov(fov);
    return 0;
}

fn setCurrentCamera(lua: *zlua.Lua) i32 {
    const camera_id = lua_funcs.pullUInt(lua, 1);
    current_camera = camera_id;
    return 0;
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
    const state = renderer.window.getKey(key_enum) == glfw.Action.release;
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

fn getMousePos(lua: *zlua.Lua) i32 {
    if (!setup_called) {
        log.err("Setup Was Not Called", .{});
        return 0;
    }
    const x = @as(f32, @floatCast(renderer.window.getCursorPos().xpos));
    const y = @as(f32, @floatCast(renderer.window.getCursorPos().ypos));

    lua_funcs.pushVec2(lua, .{ .x = x, .y = y });
    return 1;
}
