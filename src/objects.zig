const std = @import("std");
const math = std.math;

const vectors = @import("vectors.zig");

pub const Component = union(enum) {
    wall: vectors.Transform3D,
};

pub const Camera = struct {
    origin: vectors.Vec3,
    rotation: vectors.Vec3,
    orientation: vectors.Quaternion,
    fov: f32,

    rad_rotation: vectors.Vec3,
    rad_fov: f32,
    proj_dist: f32,

    const Self = @This();

    pub fn init(origin: vectors.Vec3, rotation: vectors.Vec3, orientation: vectors.Quaternion, fov: f32, screen_width: u32) Self {
        const rad_fov = math.degreesToRadians(fov);
        return .{
            .origin = origin,
            .rotation = rotation,
            .orientation = orientation,
            .fov = fov,
            .rad_fov = rad_fov,
            .rad_rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) },
            .proj_dist = (@as(f32, @floatFromInt(screen_width)) / 2.0) / math.tan(rad_fov / 2.0),
        };
    }

    pub fn update_fov(self: *Self, screen_width: u32) void {
        self.*.rad_fov = math.degreesToRadians(self.fov);
        self.*.proj_dist = (@as(f32, @floatFromInt(screen_width)) / 2.0) / math.tan(self.fov / 2.0);
    }

    pub fn update_rotation(self: *Self) void {
        self.*.rad_rotation = .{ .x = math.degreesToRadians(self.rotation.x), .y = math.degreesToRadians(self.rotation.y), .z = math.degreesToRadians(self.rotation.z) };
    }
};
