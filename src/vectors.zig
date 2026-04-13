const std = @import("std");
const math = std.math;

pub const Vec2 = struct {
    x: f32,
    y: f32,

    const Self = @This();

    pub fn create(x: f32, y: f32) Self {
        return .{ .x = x, .y = y };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    const Self = @This();

    pub fn create(r: u8, g: u8, b: u8, a: u8) Self {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
};

pub const Gradient = struct {
    start: Color,
    end: Color,
    type: GradientType,
};

pub const GradientType = enum {
    LeftRight,
    UpDown,
    Center,
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();

    pub fn create(x: f32, y: f32, z: f32) Self {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn length(self: *Self) f32 {
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn length_squared(self: *Self) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }
};

pub const Quaternion = struct {
    w: f32,
    x: f32,
    y: f32,
    z: f32,
};

pub const Transform2D = struct {
    position: Vec2,
    scale: Vec2,
    rotation: f32,
};

pub const Transform3D = struct {
    position: Vec3,
    scale: Vec3,
    rotation: Vec3,
    orientation: Quaternion,
};
