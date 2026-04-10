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
};

pub fn raycaster_raycast(origin: vectors.Vec3, direction: f32, game_struct: world.World) ?RaycasterRayCastReturn {
    const ray_x = origin.x + math.cos(direction);
    const ray_y = origin.z + math.sin(direction);

    var nearest_distance: f32 = math.inf(f32);

    for (game_struct.components.items) |component| {
        switch (component) {
            .wall => |wall| {
                const den: f32 = (wall.position.x - wall.scale.x) * (origin.z - ray_y) - (wall.position.z - wall.scale.z) * (origin.x - ray_x);

                if (den == 0.0) continue;

                const t: f32 = ((wall.position.x - origin.x) * (origin.z - ray_y) - (wall.position.z - origin.z) * (origin.x - ray_x)) / den;
                const u: f32 = -((wall.position.x - wall.scale.x) * (wall.position.z - origin.z) - (wall.position.z - wall.scale.z) * (wall.position.x - origin.x)) / den;

                if (!(t > 0.0 and t < 1.0 and u > 0.0 and u < nearest_distance)) continue;

                nearest_distance = u;
            },
        }
    }

    return .{ .distance = nearest_distance };
}

// //const angle: f32 = angle_origin - math.atan(@as(f32, @floatFromInt(n)) / proj_dist);
//                 const ray_x = camera.origin.x + math.cos(angle);
//                 const ray_y = camera.origin.z + math.sin(angle);

//                 const den: f32 = (component.wall - wall_x2) * (cam_y - ray_y) - (wall_y1 - wall_y2) * (cam_x - ray_x);

//                 if (den == 0.0) continue;

//                 const t: f32 = ((wall_x1 - cam_x) * (cam_y - ray_y) - (wall_y1 - cam_y) * (cam_x - ray_x)) / den;
//                 const u: f32 = -((wall_x1 - wall_x2) * (wall_y1 - cam_y) - (wall_y1 - wall_y2) * (wall_x1 - cam_x)) / den;

//                 if (!(t > 0.0 and t < 1.0 and u > 0.0)) continue;

//                 //const rx: f32 = wall_x1 + t * (wall_x2 - wall_x1);
//                 //const ry: f32 = wall_y1 + t * (wall_y2 - wall_y1);

//                 //const r: f32 = math.sqrt((rx - cam_x) * (rx - cam_x) + (ry - cam_y) * (ry - cam_y));
