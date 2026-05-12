#version 450 core

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
    bool hit;
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

layout(std430, binding = 2) buffer RaycastBuffer {
    RaycastResult result[];
};

layout(std430, binding = 3) readonly buffer TextureBuffer {
    Texture textures[];
};

out vec4 FragColor;

void main() {
    const float x = gl_FragCoord.x;
    const float y = gl_FragCoord.y;
    const float height = float(screen_height);
    const RaycastResult hit = result[uint(x)];

    if (!hit.hit) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    const Wall wall = walls[hit.wall_id];

    const float cr = hit.distance * cos(camera.rotation.y - hit.rotation);

    const float perspective = (gl_FragCoord.y - height / 2.0) / camera.projection_distance;
    const float world_perspective = perspective - tan(camera.rotation.x);
    const float world_y = camera.position.y + cr * world_perspective;

    const float wall_y_bottom = wall.start.y + hit.position * (wall.end.y - wall.start.y);
    const float wall_y_top = wall_y_bottom + wall.height;

    const float shade = 1 / (0.4 * cr);
    if (world_y >= wall_y_bottom && world_y <= wall_y_top) {
        FragColor = vec4(shade, shade, shade, 1.0);
    } else {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
