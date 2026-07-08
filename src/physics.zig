const std = @import("std");
const math = std.math;

const object_manager = @import("object_manager.zig");
const vectors = @import("vectors.zig");

pub const RayResult = extern struct {
    surface_id: u32,
    distance: f32,
    uv: vectors.Vec2,
};
