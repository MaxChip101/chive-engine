const std = @import("std");
const heap = std.heap;
const zig_ast = std.zig.Ast;
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

    const file = try std.fs.cwd().createFile("types/chive.d.lua", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("-- Auto Generated\n\n");

    const enums = .{
        .{ "TextureType", types.TextureType },
        .{ "DisplayMode", types.DisplayMode },
        .{ "BillboardMode", types.BillboardMode },
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
        \\---@field normalize fun(a: Vec2)
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
        \\---@field normalize fun(a: Vec3)
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

    const source = @embedFile("src/main.zig");

    var ast = try zig_ast.parse(allocator, source, .zig);
    defer ast.deinit(allocator);

    try writer.writeAll("---@class chive\n");

    for (ast.tokens.items(.tag), 0..) |tag, i| {
        if (tag == .doc_comment) {
            const slice = ast.tokenSlice(@intCast(i));

            try writer.print("---@field {s}\n", .{slice[9..]});
        }
    }

    try writer.writeAll(
        \\
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
