const std = @import("std");
const math = std.math;

const objects = @import("objects.zig");
const vectors = @import("vectors.zig");
const world = @import("world.zig");

pub const RayCastReturn = struct {
    hit_position: vectors.Vec3,
};

pub fn raycast2D() ?RayCastReturn {}

pub const RaycasterRayCastReturn = struct {
    distance: f32,
    pos: f32,
    wall: objects.Wall,
};

pub fn wall_raycast2D(origin: vectors.Vec2, direction: f32, game_struct: world.World) ?RaycasterRayCastReturn {
    const ray_x = origin.x + math.cos(direction);
    const ray_y = origin.y + math.sin(direction);

    var nearest_distance: f32 = math.inf(f32);
    var nearest_wall: objects.Wall = undefined;
    var nearest_pos: f32 = undefined;

    for (game_struct.walls.items) |wall| {
        const den: f32 = (wall.start.x - wall.end.x) * (origin.y - ray_y) - (wall.start.z - wall.end.z) * (origin.x - ray_x);

        if (den == 0.0) continue;

        const t: f32 = ((wall.start.x - origin.x) * (origin.y - ray_y) - (wall.start.z - origin.y) * (origin.x - ray_x)) / den;
        const u: f32 = -((wall.start.x - wall.end.x) * (wall.start.z - origin.y) - (wall.start.z - wall.end.z) * (wall.start.x - origin.x)) / den;

        if (!(t >= 0.0 and t <= 1.0 and u > 0.0 and u < nearest_distance)) continue;

        nearest_distance = u;
        nearest_wall = wall;
        nearest_pos = t;
    }

    return .{ .distance = nearest_distance, .wall = nearest_wall, .pos = nearest_pos };
}
