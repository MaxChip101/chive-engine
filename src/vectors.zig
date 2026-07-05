const std = @import("std");
const math = std.math;

pub const Vec2 = extern struct { // 2
    x: f32,
    y: f32,

    const Self = @This();

    pub const zero: Self = .{ .x = 0.0, .y = 0.0 };
    pub const one: Self = .{ .x = 1.0, .y = 1.0 };
    pub const right: Self = .{ .x = 1.0, .y = 0 };
    pub const up: Self = .{ .x = 0.0, .y = 1.0 };

    pub fn length(self: Self) f32 {
        return math.sqrt(self.length_squared());
    }

    pub fn length_squared(self: Self) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn multiplyAssign(self: *Self, scalar: f32) void {
        self.*.x *= scalar;
        self.*.y *= scalar;
    }

    pub fn divideAssign(self: *Self, scalar: f32) void {
        self.*.x /= scalar;
        self.*.y /= scalar;
    }

    pub fn addAssign(self: *Self, vec: Vec2) void {
        self.*.x += vec.x;
        self.*.y += vec.y;
    }

    pub fn subtractAssign(self: *Self, vec: Vec2) void {
        self.*.x -= vec.x;
        self.*.y -= vec.y;
    }

    pub fn multiply(self: *Self, scalar: f32) Self {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }

    pub fn divide(self: *Self, scalar: f32) Self {
        return .{
            .x = self.x / scalar,
            .y = self.y / scalar,
        };
    }

    pub fn add(self: *Self, vec: Vec2) Self {
        return .{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
        };
    }

    pub fn subtract(self: *Self, vec: Vec2) Self {
        return .{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
        };
    }

    pub fn dot(self: Self, vec: Vec2) f32 {
        return self.x * vec.x + self.y * vec.y;
    }

    pub fn cross(self: Self, vec: Vec2) f32 {
        return self.x * vec.y - self.y * vec.x;
    }

    pub fn normalize(self: *Self) void {
        const _length = self.length();
        if (_length == 0) return;

        self.*.x = self.x / _length;
        self.*.y = self.y / _length;
    }

    pub fn unit(self: Self) Vec2 {
        const _length = self.length();
        if (_length == 0) return .zero;

        return .{ .x = self.x / _length, .y = self.y / _length };
    }
};

pub const Color = extern struct { // 4
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    const Self = @This();

    pub const zero: Self = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 };
    pub const black: Self = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const white: Self = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
};

pub const Vec3 = extern struct { // 3
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();

    pub const zero: Self = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    pub const one: Self = .{ .x = 1.0, .y = 1.0, .z = 1.0 };
    pub const up: Self = .{ .x = 0, .y = 1.0, .z = 0 };
    pub const right: Self = .{ .x = 1.0, .y = 0, .z = 0 };
    pub const forward: Self = .{ .x = 0, .y = 0, .z = 1.0 };

    pub fn length(self: Self) f32 {
        return math.sqrt(self.length_squared());
    }

    pub fn length_squared(self: Self) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn multiplyAssign(self: *Self, scalar: f32) void {
        self.*.x *= scalar;
        self.*.y *= scalar;
        self.*.z *= scalar;
    }

    pub fn divideAssign(self: *Self, scalar: f32) void {
        self.*.x /= scalar;
        self.*.y /= scalar;
        self.*.z /= scalar;
    }

    pub fn addAssign(self: *Self, vec: Vec3) void {
        self.*.x += vec.x;
        self.*.y += vec.y;
        self.*.z += vec.z;
    }

    pub fn subtractAssign(self: *Self, vec: Vec3) void {
        self.*.x -= vec.x;
        self.*.y -= vec.y;
        self.*.z -= vec.z;
    }

    pub fn multiply(self: Self, scalar: f32) Self {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    pub fn divide(self: Self, scalar: f32) Self {
        return .{
            .x = self.x / scalar,
            .y = self.y / scalar,
            .z = self.z / scalar,
        };
    }

    pub fn add(self: Self, vec: Vec3) Self {
        return .{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
            .z = self.z + vec.z,
        };
    }

    pub fn subtract(self: Self, vec: Vec3) Self {
        return .{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
            .z = self.z - vec.z,
        };
    }

    pub fn dot(self: Self, vec: Vec3) f32 {
        return self.x * vec.x + self.y * vec.y + self.z * vec.z;
    }

    pub fn cross(self: Self, vec: Vec3) Self {
        return .{
            .x = self.y * vec.z - self.z * vec.y,
            .y = self.z * vec.x - self.x * vec.z,
            .z = self.x * vec.y - self.y * vec.x,
        };
    }

    pub fn normalize(self: *Self) void {
        const _length = self.length();
        if (_length == 0) return;

        self.*.x = self.x / _length;
        self.*.y = self.y / _length;
        self.*.z = self.z / _length;
    }

    pub fn unit(self: Self) Self {
        const _length = self.length();

        if (_length == 0) return .zero;

        return .{
            .x = self.x / _length,
            .y = self.y / _length,
            .z = self.z / _length,
        };
    }
};
