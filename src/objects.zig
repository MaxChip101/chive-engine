const std = @import("std");
const math = std.math;

const vectors = @import("vectors.zig");
const renderer = @import("renderer.zig");

pub const Component = union(enum) {
    wall: struct {
        start: vectors.Vec3,
        end: vectors.Vec3,
        height: f32,
        color: vectors.Color,
    },
};

pub const Material = union(enum) {
    color: vectors.Color,
    gradient: vectors.Gradient,
    //texture: type,
};

// walls can just only be textures

pub const Wall = struct {
    line: vectors.Line3,
    height: f32,
    material: Material,
};

pub const Camera = struct {
    position: vectors.Vec3,
    rotation: vectors.Vec3,
    orientation: vectors.Quaternion,
    fov: f32,

    renderer_struct: renderer.Renderer,

    rad_rotation: vectors.Vec3,
    rad_fov: f32,
    proj_dist: f32,

    const Self = @This();

    pub fn init(position: vectors.Vec3, rotation: vectors.Vec3, orientation: vectors.Quaternion, fov: f32, renderer_struct: renderer.Renderer) Self {
        const rad_fov = math.degreesToRadians(fov);
        return .{
            .position = position,
            .rotation = rotation,
            .orientation = orientation,
            .fov = fov,
            .rad_fov = rad_fov,
            .rad_rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) },
            .proj_dist = (@as(f32, @floatFromInt(renderer_struct.width)) / 2.0) / math.tan(rad_fov / 2.0),
            .renderer_struct = renderer_struct,
        };
    }

    pub fn update_fov(self: *Self) void {
        self.*.rad_fov = math.degreesToRadians(self.fov);
        self.*.proj_dist = (@as(f32, @floatFromInt(self.renderer_struct.width)) / 2.0) / math.tan(self.fov / 2.0);
    }

    pub fn update_rotation(self: *Self) void {
        self.*.rad_rotation = .{ .x = math.degreesToRadians(self.rotation.x), .y = math.degreesToRadians(self.rotation.y), .z = math.degreesToRadians(self.rotation.z) };
    }
};
