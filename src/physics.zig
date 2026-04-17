const std = @import("std");
const math = std.math;

const objects = @import("objects.zig");
const vectors = @import("vectors.zig");
const world = @import("world.zig");

pub const RayCastReturn = struct {
    hit_position: vectors.Vec3,
};

const MAX_RAYCAST_WALL_COLLSION: comptime_int = 16;

pub fn raycast2D() ?RayCastReturn {}

pub const RaycasterRayCastReturn = struct {
    distance: f32,
    pos: f32,
    wall: objects.Wall,
};

fn ray_cast_compare(context: void, a: RaycasterRayCastReturn, b: RaycasterRayCastReturn) bool {
    _ = context;
    return a.distance > b.distance;
}

pub fn aabb_line(a: vectors.Line3, b: vectors.Line3) bool {
    if (a.max_x() < b.min_x() or a.min_x() > b.max_x()) return false;
    if (a.max_y() < b.min_y() or a.min_y() > b.max_y()) return false;
    if (a.max_z() < b.min_z() or a.min_z() > b.max_z()) return false;
    return true;
}

pub fn wall_raycast2D(origin: vectors.Vec2, direction: f32, game_struct: world.World) ?[]RaycasterRayCastReturn {
    const ray_x = origin.x + math.cos(direction);
    const ray_y = origin.y + math.sin(direction);

    var collided: [MAX_RAYCAST_WALL_COLLSION]RaycasterRayCastReturn = undefined;

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

    std.mem.sort(RaycasterRayCastReturn, &collided, {}, ray_cast_compare);
    return &collided;
}
