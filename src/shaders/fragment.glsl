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
uniform uint max_walls;
uniform uint render_scale;

layout(std430, binding = 2) buffer RaycastBuffer {
    RaycastResult result[];
};

layout(std430, binding = 3) readonly buffer TextureBuffer {
    Texture textures[];
};

out vec4 FragColor;

void main() {
    const uint x = uint(gl_FragCoord.x) / render_scale;
    const float height = float(screen_height);
    const float perspective = ((gl_FragCoord.y - height / 2.0) / camera.projection_distance) /* - tan(camera.rotation.x) */ ;

    // get array start & end for x coordinate range
    // loop over array & blend as needed

    vec4 pixel_color = vec4(0, 0, 0, 0);

    for (uint i = x * max_walls; i < max_walls * (x + 1); i++) {
        const RaycastResult hit = result[i];
        if (isinf(hit.distance)) {
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            continue;
        }
        const Wall wall = walls[hit.wall_id];

        const float cr = hit.distance * cos(camera.rotation.y - hit.rotation);
        const float world_y = camera.position.y + cr * perspective;
        const float wall_y_bottom = wall.start.y + hit.position * (wall.end.y - wall.start.y);
        const float wall_y_top = wall_y_bottom + wall.height;
        const float shade = 1 / (0.4 * cr);
        if (world_y >= wall_y_bottom && world_y <= wall_y_top) {
            pixel_color = mix(pixel_color, vec4(1.0, 1.0, 1.0, 1.0), (pixel_color.w + 1.0) / 2);
        }
    }
    FragColor = pixel_color;
}
