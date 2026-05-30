const std = @import("std");
const mem = std.mem;

const vectors = @import("vectors.zig");
const tools = @import("tools.zig");

const zlua = @import("zlua");

var lua: *zlua.Lua = undefined;

const push_idx = -2;
const stack_top_idx = -1;

pub fn init(allocator: mem.Allocator) !void {
    lua = try zlua.Lua.init(allocator);
    lua.openLibs();

    const main_script = try tools.path_from_binaryZ(allocator, "scripts/main.lua");
    defer allocator.free(main_script);

    lua.doFile(main_script) catch |err| {
        std.debug.print("{any}", .{err});
        return err;
    };
}

pub fn deinit() void {
    lua.deinit();
}

pub fn start() !void {
    _ = lua.getGlobal("Start") catch unreachable;
    try lua.protectedCall(.{});
}

pub fn update(delta_time: f32) !void {
    _ = lua.getGlobal("Update") catch unreachable;
    lua.pushNumber(delta_time);
    try lua.protectedCall(.{ .args = 1 });
}

pub fn tick(delta_time: f32) !void {
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
