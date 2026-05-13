const std = @import("std");
const math = std.math;

const objects = @import("objects.zig");
const vectors = @import("vectors.zig");
const world = @import("world.zig");

pub const RayCastResult = extern struct {
    wall_id: u32,
    distance: f32,
    position: f32,
    rotation: f32,
};
