const std = @import("std");
const log = std.log;

const zlua = @import("zlua");
const vectors = @import("vectors.zig");

pub const vec3_funcs = [_]zlua.FnReg{
    .{ .name = "add", .func = zlua.wrap(vec3Add) },
    .{ .name = "subtract", .func = zlua.wrap(vec3Subtract) },
    .{ .name = "multiply", .func = zlua.wrap(vec3Multiply) },
    .{ .name = "divide", .func = zlua.wrap(vec3Divide) },
    .{ .name = "addAssign", .func = zlua.wrap(vec3AddAssign) },
    .{ .name = "subtractAssign", .func = zlua.wrap(vec3SubtractAssign) },
    .{ .name = "multiplyAssign", .func = zlua.wrap(vec3MultiplyAssign) },
    .{ .name = "divideAssign", .func = zlua.wrap(vec3DivideAssign) },
    .{ .name = "length", .func = zlua.wrap(vec3Length) },
    .{ .name = "lengthSquared", .func = zlua.wrap(vec3LengthSquared) },
    .{ .name = "dot", .func = zlua.wrap(vec3Dot) },
    .{ .name = "cross", .func = zlua.wrap(vec3Cross) },
    .{ .name = "unit", .func = zlua.wrap(vec3Unit) },
};

pub const vec2_funcs = [_]zlua.FnReg{
    .{ .name = "add", .func = zlua.wrap(vec2Add) },
    .{ .name = "subtract", .func = zlua.wrap(vec2Subtract) },
    .{ .name = "multiply", .func = zlua.wrap(vec2Multiply) },
    .{ .name = "divide", .func = zlua.wrap(vec2Divide) },
    .{ .name = "addAssign", .func = zlua.wrap(vec2AddAssign) },
    .{ .name = "subtractAssign", .func = zlua.wrap(vec2SubtractAssign) },
    .{ .name = "multiplyAssign", .func = zlua.wrap(vec2MultiplyAssign) },
    .{ .name = "divideAssign", .func = zlua.wrap(vec2DivideAssign) },
    .{ .name = "length", .func = zlua.wrap(vec2Length) },
    .{ .name = "lengthSquared", .func = zlua.wrap(vec2LengthSquared) },
    .{ .name = "dot", .func = zlua.wrap(vec2Dot) },
    .{ .name = "cross", .func = zlua.wrap(vec2Cross) },
    .{ .name = "unit", .func = zlua.wrap(vec2Unit) },
};

const push_idx = -2;
const stack_top_idx = -1;

// call funcs

pub fn update(lua: *zlua.Lua, delta_time: f32) !void {
    _ = lua.getGlobal("Update") catch unreachable;
    lua.pushNumber(delta_time);
    lua.protectedCall(.{ .args = 1 }) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        return error.LuaRuntime;
    };
}

pub fn fixedUpdate(lua: *zlua.Lua, fixed_delta_time: f32) !void {
    _ = lua.getGlobal("FixedUpdate") catch unreachable;
    lua.pushNumber(fixed_delta_time);
    lua.protectedCall(.{ .args = 1 }) catch {
        const err_msg = lua.toString(stack_top_idx) catch "unkown error";
        log.err("Lua Error: {s}", .{err_msg});
        lua.pop(1);
        return error.LuaRuntime;
    };
}

// recieve funcs

pub fn pushVec3(lua: *zlua.Lua, vector: vectors.Vec3) void {
    lua.createTable(0, 3);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
    lua.pushNumber(vector.z);
    lua.setField(push_idx, "z");
}

pub fn pullVec3(lua: *zlua.Lua, idx: i32) vectors.Vec3 {
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

pub fn pushVec2(lua: *zlua.Lua, vector: vectors.Vec2) void {
    lua.createTable(0, 2);
    lua.pushNumber(vector.x);
    lua.setField(push_idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(push_idx, "y");
}

pub fn pullVec2(lua: *zlua.Lua, idx: i32) vectors.Vec2 {
    _ = lua.getField(idx, "x");
    const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    _ = lua.getField(idx, "y");
    const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
    lua.pop(1);
    return .{ .x = x, .y = y };
}

pub fn writeVec2(lua: *zlua.Lua, idx: i32, vector: vectors.Vec2) void {
    lua.pushNumber(vector.x);
    lua.setField(idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(idx, "y");
}

pub fn writeVec3(lua: *zlua.Lua, idx: i32, vector: vectors.Vec3) void {
    lua.pushNumber(vector.x);
    lua.setField(idx, "x");
    lua.pushNumber(vector.y);
    lua.setField(idx, "y");
    lua.pushNumber(vector.z);
    lua.setField(idx, "z");
}

pub fn pushColor(lua: *zlua.Lua, color: vectors.Color) void {
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

pub fn pullColor(lua: *zlua.Lua, idx: i32) vectors.Color {
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

pub fn vec2Length(lua: *zlua.Lua) i32 {
    const vector = pullVec2(lua, 1);
    lua.pushNumber(vector.length());
    return 1;
}

pub fn vec2LengthSquared(lua: *zlua.Lua) i32 {
    const vector = pullVec2(lua, 1);
    lua.pushNumber(vector.length_squared());
    return 1;
}

pub fn vec2AddAssign(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    vector1.addAssign(vector2);
    writeVec2(lua, 1, vector1);
    return 0;
}

pub fn vec2SubtractAssign(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    vector1.subtractAssign(vector2);
    writeVec2(lua, 1, vector1);
    return 0;
}

pub fn vec2MultiplyAssign(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.multiplyAssign(scalar);
    writeVec2(lua, 1, vector);
    return 0;
}

pub fn vec2DivideAssign(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.divideAssign(scalar);
    writeVec2(lua, 1, vector);
    return 0;
}

pub fn vec2Add(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    const result = vector1.add(vector2);
    pushVec2(lua, result);
    return 1;
}

pub fn vec2Subtract(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    const result = vector1.subtract(vector2);
    pushVec2(lua, result);
    return 1;
}

pub fn vec2Multiply(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    const result = vector.multiply(scalar);
    pushVec2(lua, result);
    return 1;
}

pub fn vec2Divide(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    const scalar = pullNumber(lua, 2);
    const result = vector.divide(scalar);
    pushVec2(lua, result);
    return 1;
}

pub fn vec2Dot(lua: *zlua.Lua) i32 {
    const vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    lua.pushNumber(vector1.dot(vector2));
    return 1;
}

pub fn vec2Cross(lua: *zlua.Lua) i32 {
    var vector1 = pullVec2(lua, 1);
    const vector2 = pullVec2(lua, 2);
    lua.pushNumber(vector1.cross(vector2));
    return 1;
}

pub fn vec2Unit(lua: *zlua.Lua) i32 {
    var vector = pullVec2(lua, 1);
    pushVec2(lua, vector.unit());
    return 1;
}

pub fn vec3Length(lua: *zlua.Lua) i32 {
    const vector = pullVec3(lua, 1);
    lua.pushNumber(vector.length());
    return 1;
}

pub fn vec3LengthSquared(lua: *zlua.Lua) i32 {
    const vector = pullVec3(lua, 1);
    lua.pushNumber(vector.length_squared());
    return 1;
}

pub fn vec3AddAssign(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    vector1.addAssign(vector2);
    writeVec3(lua, 1, vector1);
    return 0;
}

pub fn vec3SubtractAssign(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    vector1.subtractAssign(vector2);
    writeVec3(lua, 1, vector1);
    return 0;
}

pub fn vec3MultiplyAssign(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.multiplyAssign(scalar);
    writeVec3(lua, 1, vector);
    return 0;
}

pub fn vec3DivideAssign(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    vector.divideAssign(scalar);
    writeVec3(lua, 1, vector);
    return 0;
}

pub fn vec3Add(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    const result = vector1.add(vector2);
    pushVec3(lua, result);
    return 1;
}

pub fn vec3Subtract(lua: *zlua.Lua) i32 {
    var vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    const result = vector1.subtract(vector2);
    pushVec3(lua, result);
    return 1;
}

pub fn vec3Multiply(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    const result = vector.multiply(scalar);
    pushVec3(lua, result);
    return 1;
}

pub fn vec3Divide(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    const scalar = pullNumber(lua, 2);
    const result = vector.divide(scalar);
    pushVec3(lua, result);
    return 1;
}

pub fn vec3Dot(lua: *zlua.Lua) i32 {
    const vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    lua.pushNumber(vector1.dot(vector2));
    return 1;
}

pub fn vec3Cross(lua: *zlua.Lua) i32 {
    const vector1 = pullVec3(lua, 1);
    const vector2 = pullVec3(lua, 2);
    pushVec3(lua, vector1.cross(vector2));
    return 1;
}

pub fn vec3Unit(lua: *zlua.Lua) i32 {
    var vector = pullVec3(lua, 1);
    pushVec3(lua, vector.unit());
    return 1;
}

pub fn pullNumber(lua: *zlua.Lua, idx: i32) f32 {
    return @floatCast(lua.toNumber(idx) catch 0.0);
}

pub fn pullInt(lua: *zlua.Lua, idx: i32) i32 {
    return @intCast(lua.toInteger(idx) catch 0);
}

pub fn pullUInt(lua: *zlua.Lua, idx: i32) u32 {
    return @intCast(lua.toInteger(idx) catch 0);
}

pub fn pullBool(lua: *zlua.Lua, idx: i32) bool {
    return lua.toBoolean(idx);
}

pub fn pullString(lua: *zlua.Lua, idx: i32) [:0]const u8 {
    return lua.toString(idx) catch "";
}
