const std = @import("std");
const mem = std.mem;

const vectors = @import("vectors.zig");

const zlua = @import("zlua");

const Program = struct {
    lua: zlua.Lua,
    main_script: []u8,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const lua = try zlua.Lua.init(allocator);

        lua.openLibs();

        return .{
            .lua = lua,
        };
    }

    const vec3_stack_idx = -3;
    const vec2_stack_idx = -2;

    pub fn deinit(self: Self) void {
        self.lua.deinit();
    }

    pub fn start(self: *Self) !void {
        self.lua.getGlobal("Start") catch unreachable;
        try self.lua.protectedCall(.{ 0, 0, 0 });
    }

    fn pushVec3(self: Self, vector: vectors.Vec3) void {
        self.lua.createTable(0, 3);
        self.lua.pushNumber(vector.x);
        self.lua.setField(vec3_stack_idx, "x");
        self.lua.pushNumber(vector.y);
        self.lua.setField(vec3_stack_idx, "y");
        self.lua.pushNumber(vector.z);
        self.lua.setField(vec3_stack_idx, "z");
    }

    fn pullVec3(self: Self, idx: i32) vectors.Vec3 {
        self.lua.getField(idx, "x");
        const x: f32 = @floatCast(self.lua.toNumber(-1) catch 0);
        self.lua.pop(1);
        self.lua.getField(idx, "y");
        const y: f32 = @floatCast(self.lua.toNumber(-1) catch 0);
        self.lua.pop(1);
        self.lua.getField(idx, "z");
        const z: f32 = @floatCast(self.lua.toNumber(-1) catch 0);
        self.lua.pop(1);
        return .{ .x = x, .y = y, .z = z };
    }

    fn pushVec2(self: Self, vector: vectors.Vec2) void {
        self.lua.createTable(0, 3);
        self.lua.pushNumber(vector.x);
        self.lua.setField(vec2_stack_idx, "x");
        self.lua.pushNumber(vector.y);
        self.lua.setField(vec2_stack_idx, "y");
    }

    fn pullVec2(self: Self, idx: i32) vectors.Vec2 {
        self.lua.getField(idx, "x");
        const x: f32 = @floatCast(self.lua.toNumber(-1) catch 0);
        self.lua.pop(1);
        self.lua.getField(idx, "y");
        const y: f32 = @floatCast(self.lua.toNumber(-1) catch 0);
        self.lua.pop(1);
        return .{ .x = x, .y = y };
    }
};
