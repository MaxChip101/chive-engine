const std = @import("std");
const math = std.math;

const vectors = @import("vectors.zig");
const renderer = @import("renderer.zig");

pub const Wall = extern struct {
    start: vectors.Vec3,
    height: f32,
    end: vectors.Vec3,
    texture_id: u32,
};

pub const Plane = extern struct {
    start: vectors.Vec2,
    end: vectors.Vec2,
    vertical: f32,
    texture_id: u32,
};

pub const Camera = extern struct {
    position: vectors.Vec3,
    fov: f32,
    rotation: vectors.Vec3,
    projection_distance: f32,

    const Self = @This();

    pub fn init(position: vectors.Vec3, rotation: vectors.Vec3, fov: f32, width: u32) Self {
        const rad_fov = math.degreesToRadians(fov);
        return .{
            .position = position,
            .fov = rad_fov,
            .rotation = vectors.Vec3{ .x = math.degreesToRadians(-rotation.x), .y = math.degreesToRadians(-rotation.y), .z = math.degreesToRadians(-rotation.z) },
            .projection_distance = @as(f32, @floatFromInt(width)) / (2 * math.tan(rad_fov / 2.0)),
        };
    }

    pub fn setFov(self: *Self, fov: f32) void {
        self.*.fov = math.degreesToRadians(fov);
    }

    pub fn setRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation = vectors.Vec3{ .x = math.degreesToRadians(-rotation.x), .y = math.degreesToRadians(-rotation.y), .z = math.degreesToRadians(-rotation.z) };
    }

    pub fn increaseRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation.x += math.degreesToRadians(-rotation.x);
        self.*.rotation.y += math.degreesToRadians(-rotation.y);
        self.*.rotation.z += math.degreesToRadians(-rotation.z);
    }

    pub fn updateProjectionDistance(self: *Self, width: u32) void {
        self.*.projection_distance = @as(f32, @floatFromInt(width)) / (2 * math.tan(self.fov / 2.0));
    }
};
