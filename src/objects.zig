const std = @import("std");
const math = std.math;

const vectors = @import("vectors.zig");

pub const Component = union(enum) {
    camera: struct {
        origin: vectors.Vec3,
        rotation: f32,
        fov: u8,
    },
    wall: vectors.Transform3D,
};

pub const Camera = struct {
    origin: vectors.Vec3,
    rotation: vectors.Vec3,
    orientation: vectors.Quaternion,
    fov: f32,

    rad_fov: f32,

    const Self = @This();

    pub fn init(origin: vectors.Vec3, rotation: vectors.Vec3, orientation: vectors.Quaternion, fov: f32) !Self {
        return .{
            .origin = origin,
            .rotation = rotation,
            .orientation = orientation,
            .fov = fov,
            .rad_fov = math.degreesToRadians(fov),
        };
    }
};
