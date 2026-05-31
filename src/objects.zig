const std = @import("std");
const math = std.math;

const vectors = @import("vectors.zig");

pub const Surface = extern struct {
    position: vectors.Vec3,
    rotation: f32,
    normal: vectors.Vec3,
    texture_id: u32,
    size: vectors.Vec2,
    _pad: [2]f32 = .{ 0, 0 },

    const Self = @This();
};

pub const Camera = extern struct {
    position: vectors.Vec3,
    fov: f32,
    rotation: vectors.Vec3,
    focal_length: f32,
    // direction??

    const Self = @This();

    pub fn init(position: vectors.Vec3, rotation: vectors.Vec3, fov: f32) Self {
        const rad_fov = math.degreesToRadians(fov);
        return .{
            .position = position,
            .fov = rad_fov,
            .rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) },
            .focal_length = 0.0,
        };
    }

    pub fn setFov(self: *Self, fov: f32) void {
        self.*.fov = math.degreesToRadians(fov);
    }

    pub fn setRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) };
    }

    pub fn increaseRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation.x += math.degreesToRadians(rotation.x);
        self.*.rotation.y += math.degreesToRadians(rotation.y);
        self.*.rotation.z += math.degreesToRadians(rotation.z);
    }

    pub fn updateFocalLength(self: *Self, width: u32) void {
        self.*.focal_length = @as(f32, @floatFromInt(width)) / (2 * math.tan(self.fov / 2.0));
    }
};
