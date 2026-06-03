const std = @import("std");
const heap = std.heap;
const glfw = @import("glfw");
const types = @import("types");
const tools = @import("tools");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }
    const allocator = gpa.allocator();
    _ = allocator;

    const file = try std.fs.cwd().createFile("types/chive.d.lua", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("-- Auto Generated\n\n");

    const enums = .{
        .{ "TextureType", types.TextureType },
        .{ "DisplayMode", types.DisplayMode },
        .{ "Key", glfw.Key },
        .{ "MouseState", glfw.Window.InputModeCursor },
    };

    inline for (enums) |entry| {
        try writer.print("---@class {s}\n", .{entry[0]});
        inline for (@typeInfo(entry[1]).@"enum".fields) |field| {
            try writer.print("---@field {s} {d}\n", .{ field.name, field.value });
        }
        try writer.print("\n---@type {s}\n{s} = {s}\n\n", .{ entry[0], entry[0], entry[0] });
    }

    const structs = .{
        .{ "Vec2", types.Vec2, 0 },
        .{ "Vec3", types.Vec3, 1 },
        .{ "Color", types.Color, 2 },
    };

    inline for (structs) |entry| {
        try writer.print("---@class {s}\n", .{entry[0]});
        inline for (@typeInfo(entry[1]).@"struct".fields) |field| {
            try writer.print("---@field {s} {s}\n", .{ field.name, zigTypeToLuaType(field.type) });
        }
        try writer.print("\n---@type {s}\n{s} = {s}\n\n", .{ entry[0], entry[0], entry[0] });
    }

    try writer.writeAll("---@class color\n");
    inline for (@typeInfo(structs[2][1]).@"struct".decls) |decls| {
        try writer.print("---@field {s} Color\n", .{decls.name});
    }
    try writer.writeAll(
        \\
        \\---@type color
        \\color = color
        \\
        \\
    );

    try writer.writeAll("---@class vec2\n");
    inline for (@typeInfo(structs[0][1]).@"struct".decls) |decls| {
        try writer.print("---@field {s} Vec2\n", .{decls.name});
    }
    try writer.writeAll(
        \\---@field add fun(a: Vec2, b: Vec2))
        \\---@field subtract fun(a: Vec2, b: Vec2)
        \\---@field multiply fun(a: Vec2, scalar: number)
        \\---@field divide fun(a: Vec2, scalar: number)
        \\---@field length fun(a: Vec2): number
        \\---@field lengthSquared fun(a: Vec2): number
        \\---@field dot fun(a: Vec2, b: Vec2): number
        \\---@field cross fun(a: Vec2, b: Vec2): number
        \\---@field unit fun(a: Vec2): Vec2
        \\
        \\---@type vec2
        \\vec2 = vec2
        \\
        \\
    );

    try writer.writeAll("---@class vec3\n");
    inline for (@typeInfo(structs[1][1]).@"struct".decls) |decls| {
        try writer.print("---@field {s} Vec3\n", .{decls.name});
    }
    try writer.writeAll(
        \\---@field add fun(a: Vec3, b: Vec3)
        \\---@field subtract fun(a: Vec3, b: Vec3)
        \\---@field multiply fun(a: Vec3, scalar: number)
        \\---@field divide fun(a: Vec3, scalar: number)
        \\---@field length fun(a: Vec3): number
        \\---@field lengthSquared fun(a: Vec3): number
        \\---@field dot fun(a: Vec3, b: Vec3): number
        \\---@field cross fun(a: Vec3, b: Vec3): Vec3
        \\---@field unit fun(a: Vec3): Vec3
        \\
        \\---@type vec3
        \\vec3 = vec3
        \\
        \\
    );

    //.{ .name = "setTextureUFlip", .func = zlua.wrap(setTextureUFlip) },
    //.{ .name = "setTextureVFlip", .func = zlua.wrap(setTextureVFlip) },
    //.{ .name = "setTextureAtlasID", .func = zlua.wrap(setTextureAtlasID) },

    try writer.writeAll(
        \\---@class chive
        \\---@field setup fun(title: string, size: Vec2, display_mode: integer, resolution: Vec2, texture_atlas_size: integer, texture_atlas_count: integer)
        \\---@field setTitle fun(title: string)
        \\---@field setDisplayMode fun(display_mode: integer)
        \\---@field getDisplayMode fun(): integer
        \\---@field setResizable fun(resizable: boolean)
        \\---@field setWindowSize fun(size: Vec2)
        \\---@field setMousePos fun(pos: Vec2)
        \\---@field setFps fun(fps: integer)
        \\---@field getFps fun(): integer
        \\---@field getWindowSize fun(): Vec2
        \\---@field getWindowPos fun(): Vec2
        \\---@field setWindowPos fun(position: Vec2)
        \\---@field createScene fun(): integer
        \\---@field getSceneIDs fun(): integer[]
        \\---@field deleteScene fun(scene_id: integer): boolean
        \\---@field setCurrentScene fun(scene_id: integer)
        \\---@field getCurrentScene fun(): integer
        \\---@field createTexture fun(atlas_id: integer, uv_min: Vec2, uv_max: Vec2, texture_type: integer, flip_u: boolean, flip_v: boolean, tint: Color, size: Vec2): integer
        \\---@field getTextureIDs fun(): integer[]
        \\---@field getTextureUVMin fun(texture_id: integer): Vec2
        \\---@field getTextureUVMax fun(texture_id: integer): Vec2
        \\---@field getTextureSize fun(texture_id: integer): Vec2
        \\---@field getTextureTint fun(texture_id: integer): Color
        \\---@field getTextureUFlip fun(texture_id: integer): boolean
        \\---@field getTextureVFlip fun(texture_id: integer): boolean
        \\---@field getTextureAtlasID fun(texture_id: integer): integer
        \\---@field setTextureUVMin fun(texture_id: integer, uv_min: Vec2)
        \\---@field setTextureUVMax fun(texture_id: integer, uv_max: Vec2)
        \\---@field setTextureSize fun(texture_id: integer, size: Vec2)
        \\---@field setTextureTint fun(texture_id: integer, tint: Color)
        \\---@field setTextureUFlip fun(texture_id: integer, flip_u: boolean)
        \\---@field setTextureVFlip fun(texture_id: integer, flip_v: boolean)
        \\---@field setTextureAtlasID fun(texture_id: integer, atlas_id: integer)
        \\---@field removeTexture fun(texture_id: integer): boolean
        \\---@field loadTextureAtlas fun(atlas_path: string): integer
        \\---@field createSurface fun(position: Vec3, normal: Vec3, rotation: number, size: Vec2, texture_id: integer): integer
        \\---@field getSurfacePosition fun(surface_id: integer): Vec3
        \\---@field getSurfaceNormal fun(surface_id: integer): Vec3
        \\---@field getSurfaceRotation fun(surface_id: integer): number
        \\---@field getSurfaceRadRotation fun(surface_id: integer): number
        \\---@field getSurfaceSize fun(surface_id: integer): Vec2
        \\---@field getSurfaceTextureID fun(surface_id: integer): integer
        \\---@field setSurfacePosition fun(surface_id: integer, position: Vec3)
        \\---@field setSurfaceNormal fun(surface_id: integer, normal: Vec3)
        \\---@field setSurfaceRotation fun(surface_id: integer, rotation: number)
        \\---@field setSurfaceRadRotation fun(surface_id: integer, rad_rotation: number)
        \\---@field setSurfaceSize fun(surface_id: integer, size: Vec2)
        \\---@field setSurfaceTextureID fun(surface_id: integer, texture_id: integer)
        \\---@field removeSurface fun(surface_id: integer): boolean
        \\---@field createCamera fun(position: Vec3, rotation: Vec3, fov: number): integer
        \\---@field getCameraIDs fun(): integer[]
        \\---@field getCameraPosition fun(camera_id: integer): Vec3
        \\---@field getCameraRotation fun(camera_id: integer): Vec3
        \\---@field getCameraRadRotation fun(camera_id: integer): Vec3
        \\---@field getCameraRadFov fun(camera_id: integer): number
        \\---@field getCameraFov fun(camera_id: integer): number
        \\---@field setCameraPosition fun(camera_id: integer, position: Vec3)
        \\---@field setCameraRotation fun(camera_id: integer, rotation: Vec3)
        \\---@field setCameraRadRotation fun(camera_id: integer, rad_rotation: Vec3)
        \\---@field setCameraRadFov fun(camera_id: integer, rad_fov: number)
        \\---@field setCameraFov fun(camera_id: integer, fov: number)
        \\---@field deleteCamera fun(camera_id: integer): boolean
        \\---@field setCurrentCamera fun(camera_id: integer)
        \\---@field getCurrentCamera fun(): integer
        \\---@field getKeyDown fun(key: integer): boolean
        \\---@field getKeyUp fun(key: integer): boolean
        \\---@field getKeyPressed fun(key: integer): boolean
        \\---@field getKeyReleased fun(key: integer): boolean
        \\---@field getKeyRepeat fun(key: integer): boolean
        \\---@field setMouseState fun(mouse_state: integer)
        \\---@field getMouseState fun(): integer
        \\---@field getMousePos fun(): Vec2
        \\
        \\
    );

    try writer.writeAll(
        \\---@type chive
        \\chive = chive
        \\
        \\---@param fixed_delta number
        \\function FixedUpdate(fixed_delta) end
        \\
        \\---@param delta number
        \\function Update(delta) end
        \\
    );
}

fn zigTypeToLuaType(comptime T: type) []const u8 {
    return switch (T) {
        f32, f64 => "number",
        i8, i16, i32, i64, u8, u16, u32, u64 => "integer",
        bool => "boolean",
        []const u8, [:0]const u8 => "string",
        else => "any",
    };
}
