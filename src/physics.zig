const std = @import("std");
const math = std.math;

const objects = @import("objects.zig");
const vectors = @import("vectors.zig");
const world = @import("world.zig");

pub const RayResult = extern struct {
    surface_id: u32,
    distance: f32,
    uv: vectors.Vec2,
};
