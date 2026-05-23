#version 450 core

const float INF = 1e10;

struct Texture {
    vec2 uv_min;
    vec2 uv_max;
    vec4 tint;
    uint atlas_id;
    bool flip_v;
    bool flip_h;
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

uniform sampler2DArray texture_atlas;

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
    const float perspective = ((gl_FragCoord.y - height / 2.0) / camera.projection_distance) - tan(camera.rotation.x);

    // get array start & end for x coordinate range
    // loop over array & blend as needed
    // apply textures and make colors mix only when translucent

    vec4 pixel_color = vec4(0, 0, 0, 0);

    for (uint i = x * max_walls; i < max_walls * (x + 1); i++) {
        const RaycastResult hit = result[i];
        if (hit.distance > INF) {
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            continue;
        }
        const Wall wall = walls[hit.wall_id];
        const Texture tex = textures[wall.texture_id];

        const float cr = hit.distance * cos(camera.rotation.y - hit.rotation);
        const float world_y = camera.position.y + cr * perspective;
        const float wall_y_bottom = wall.start.y + hit.position * (wall.end.y - wall.start.y);
        const float wall_y_top = wall_y_bottom + wall.height;
        const float shade = 1 / (0.3 * cr);

        float u = mix(tex.uv_min.x, tex.uv_max.x, hit.position);
        float v = mix(tex.uv_min.y, tex.uv_max.y, (world_y - wall_y_bottom) / wall.height);

        if (tex.flip_v) u *= -1;
        if (tex.flip_h) v *= -1;

        vec4 pixel = texture(texture_atlas, vec3(u, v, float(tex.atlas_id)));

        pixel.rgb *= shade;

        if (world_y >= wall_y_bottom && world_y <= wall_y_top) {
            if (pixel_color == vec4(0, 0, 0, 0) && pixel.a == 1.0) {
                pixel_color = pixel + pixel_color * (1.0 - pixel.a);
            }
        }
    }
    FragColor = pixel_color;
}
