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
        .{ "DisplayMethod", types.DisplayMethod },
        .{ "Key", glfw.Key },
        .{ "MouseState", glfw.Window.InputModeCursor },
    };

    inline for (enums) |entry| {
        try writer.print("---@class {s}\n", .{entry[0]});
        inline for (@typeInfo(entry[1]).@"enum".fields) |field| {
            try writer.print("---@field {s} {d} \n", .{ field.name, field.value });
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
            try writer.print("---@field {s} {s} \n", .{ field.name, zigTypeToLuaType(field.type) });
        }
        try writer.print("\n---@type {s}\n{s} = {s}\n\n", .{ entry[0], entry[0], entry[0] });
    }

    try writer.writeAll("---@class vec2\n");
    try writer.writeAll("---@field add fun(a: Vec2, b: Vec2): void\n");
    try writer.writeAll("---@field subtract fun(a: Vec2, b: Vec2): void\n");
    try writer.writeAll("---@field multiply fun(a: Vec2, scalar: number): void\n");
    try writer.writeAll("---@field divide fun(a: Vec2, scalar: number): void\n");
    try writer.writeAll("---@field length fun(a: Vec2): number\n");
    try writer.writeAll("---@field lengthSquared fun(a: Vec2): number\n");
    try writer.writeAll("---@field dot fun(a: Vec2, b: Vec2): number\n");
    try writer.writeAll("---@field cross fun(a: Vec2, b: Vec2): number\n");
    try writer.writeAll("---@field unit fun(a: Vec2): Vec2\n\n");
    try writer.writeAll("---@type vec2\n");
    try writer.writeAll("vec2 = vec2\n\n");

    try writer.writeAll("---@class vec3\n");
    try writer.writeAll("---@field add fun(a: Vec3, b: Vec3): void\n");
    try writer.writeAll("---@field subtract fun(a: Vec3, b: Vec3): void\n");
    try writer.writeAll("---@field multiply fun(a: Vec3, scalar: number): void\n");
    try writer.writeAll("---@field divide fun(a: Vec3, scalar: number): void\n");
    try writer.writeAll("---@field length fun(a: Vec3): number\n");
    try writer.writeAll("---@field lengthSquared fun(a: Vec3): number\n");
    try writer.writeAll("---@field dot fun(a: Vec3, b: Vec3): number\n");
    try writer.writeAll("---@field cross fun(a: Vec3, b: Vec3): Vec3\n");
    try writer.writeAll("---@field unit fun(a: Vec3): Vec3\n\n");
    try writer.writeAll("---@type vec3\n");
    try writer.writeAll("vec3 = vec3\n\n");

    try writer.writeAll(
        \\
        \\---@type chive
        \\chive = chive
        \\
        \\---@param delta number
        \\function Tick(delta) end
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
