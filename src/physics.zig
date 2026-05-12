const std = @import("std");
const math = std.math;

const objects = @import("objects.zig");
const vectors = @import("vectors.zig");
const world = @import("world.zig");

pub const RayCastReturn = struct {
    hit_position: vectors.Vec3,
};

const MAX_RAYCAST_WALL_COLLSION: comptime_int = 256;

pub fn raycast2D() ?RayCastReturn {}

pub const RayCastResult = extern struct {
    hit: bool,
    wall_id: u32,
    distance: f32,
    position: f32,
    rotation: f32,
};

pub const RayCastResultArray = extern struct {
    length: usize,
    results: [MAX_RAYCAST_WALL_COLLSION]RayCastResult,
};

fn ray_cast_compare(context: void, a: RayCastResult, b: RayCastResult) bool {
    _ = context;
    return a.distance > b.distance;
}

pub fn wall_raycast2D(origin: vectors.Vec2, direction: f32, game_struct: world.World) ?[]RayCastResult {
    const ray_x = origin.x + math.cos(direction);
    const ray_y = origin.y + math.sin(direction);

    var collided: [MAX_RAYCAST_WALL_COLLSION]RayCastResult = undefined;

    var idx: usize = 0;
    for (game_struct.walls.items) |wall| {
        const den: f32 = (wall.start.x - wall.end.x) * (origin.y - ray_y) - (wall.start.z - wall.end.z) * (origin.x - ray_x);

        if (den == 0.0) continue;

        const t: f32 = ((wall.start.x - origin.x) * (origin.y - ray_y) - (wall.start.z - origin.y) * (origin.x - ray_x)) / den;
        const u: f32 = -((wall.start.x - wall.end.x) * (wall.start.z - origin.y) - (wall.start.z - wall.end.z) * (wall.start.x - origin.x)) / den;

        if (!(t >= 0.0 and t <= 1.0 and u > 0.0)) continue;

        collided[idx] = .{ .distance = u, .pos = t, .wall = wall };
        idx += 1;
        if (idx >= MAX_RAYCAST_WALL_COLLSION - 1) break;
    }

    std.mem.sort(RayCastResult, &collided, {}, ray_cast_compare);
    return &collided;
}
