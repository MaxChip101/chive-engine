#version 450 core

const float INF = 1e10;

struct Texture {
    ivec2 dimensions;
    vec4 pixels[];
};

struct Wall {
    vec3 start;
    float height;
    vec3 end;
    uint texture_id;
};

struct Camera {
    vec3 position;
    float fov;
    vec3 rotation;
    float projection_distance;
};

struct RaycastResult {
    uint wall_id;
    float distance;
    float position;
    float rotation;
};

layout(std430, binding = 0) readonly buffer WallBuffer {
    Wall walls[];
};

layout(std430, binding = 1) readonly buffer CameraBuffer {
    Camera camera;
};

uniform int screen_width;
uniform int screen_height;
uniform uint wall_count;
uniform uint max_walls;
uniform uint render_scale;

layout(std430, binding = 2) writeonly buffer RaycastBuffer {
    RaycastResult result[];
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

void main() {
    const uint x = gl_GlobalInvocationID.x;
    const uint pixel_x = x / render_scale;

    if (x >= uint(screen_width)) {
        return;
    }

    const float angle = camera.rotation.y - atan((float(x) - float(screen_width) / 2.0) / camera.projection_distance);

    const float ray_x = camera.position.x + cos(angle);
    const float ray_y = camera.position.z + sin(angle);

    float last_biggest_distance = 0.0;

    for (int i = 0; i < max_walls; i++) {
        uint id = 0;
        float distance = INF;
        float position = 0;

        for (int wall_id = 0; wall_id < wall_count; wall_id++) {
            const Wall wall = walls[wall_id];
            const float denominator = (wall.start.x - wall.end.x) * (camera.position.z - ray_y) - (wall.start.z - wall.end.z) * (camera.position.x - ray_x);
            if (denominator == 0.0) continue;

            const float t = ((wall.start.x - camera.position.x) * (camera.position.z - ray_y) - (wall.start.z - camera.position.z) * (camera.position.x - ray_x)) / denominator;
            const float u = -((wall.start.x - wall.end.x) * (wall.start.z - camera.position.z) - (wall.start.z - wall.end.z) * (wall.start.x - camera.position.x)) / denominator;

            if (!(t >= 0.0 && t <= 1.0 && u > 0.0 && u > last_biggest_distance && u < distance)) continue;

            distance = u;
            position = t;
            id = wall_id;
        }
        if (distance < INF) last_biggest_distance = distance;
        uint result_pos = i + pixel_x * max_walls;
        result[result_pos].wall_id = id;
        result[result_pos].position = position;
        result[result_pos].distance = distance;
        result[result_pos].rotation = angle;
    }
}
