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

    pub const zero: Self = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

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

pub const Line3 = struct {
    start: Vec3,
    end: Vec3,

    const Self = @This();

    pub fn create(start: Vec3, end: Vec3) Self {
        return .{ .start = start, .end = end };
    }

    pub fn max_x(self: *Self) f32 {
        return @max(self.start.x, self.end.x);
    }

    pub fn min_x(self: *Self) f32 {
        return @min(self.start.x, self.end.x);
    }

    pub fn max_y(self: *Self) f32 {
        return @max(self.start.y, self.end.y);
    }

    pub fn min_y(self: *Self) f32 {
        return @min(self.start.y, self.end.y);
    }

    pub fn max_z(self: *Self) f32 {
        return @max(self.start.z, self.end.z);
    }

    pub fn min_z(self: *Self) f32 {
        return @min(self.start.z, self.end.z);
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
