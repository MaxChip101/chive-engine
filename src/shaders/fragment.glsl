#version 450 core

const float INF = 1e10;
const vec4 background = vec4(0, 0, 0, 0);

const uint TEXTURE_TYPE_STRETCH = 0;
const uint TEXTURE_TYPE_TILE = 1;

struct Texture {
    vec2 uv_min;
    vec2 uv_max;
    uint type;
    uint atlas_id;
    bool flip_v;
    bool flip_h;
    vec4 tint;
    vec2 size;
};

struct Surface {
    vec3 position;
    float rotation;
    vec3 normal;
    uint texture_id;
    vec2 size;
};

struct Camera {
    vec3 position;
    float fov;
    vec3 rotation;
    float projection_distance;
};

layout(std430, binding = 0) readonly buffer CameraBuffer {
    Camera camera;
};

layout(std430, binding = 1) readonly buffer TextureBuffer {
    Texture textures[];
};

layout(std430, binding = 2) readonly buffer SurfaceBuffer {
    Surface surfaces[];
};

uniform sampler2DArray texture_atlas;

uniform int screen_width;
uniform int screen_height;
uniform uint max_surfaces;
uniform uint render_scale;

out vec4 FragColor;

// rewrite, switching to 3d raycaster (raytracer or whatever)
// this would fit the criteria of having to not layer stuff
// also fix having a unified surface system

// function to shoot a ray at the pixel's angle
// view depth variable for how far a ray shoots through each wall

void cast(vec3 position, vec3 direction) {}

void main() {
    vec2 screen = vec2(screen_width, screen_height);
    vec2 screen_coord = gl_FragCoord.xy - screen / 2.0;
    vec2 rotated_coord = vec2(
            screen_coord.x * cos(camera.rotation.z) - screen_coord.y * sin(camera.rotation.z),
            screen_coord.x * sin(camera.rotation.z) + screen_coord.y * cos(camera.rotation.z)
        ) + screen / 2.0;

    const uint x = uint(rotated_coord.x) / render_scale;
    const float height = float(screen_height);
    const float perspective = ((rotated_coord.y - height / 2.0) / camera.projection_distance) - tan(camera.rotation.x);

    vec4 screen_pixel = background;

    for (uint i = x * max_walls; i < max_walls * (x + 1); i++) {
        const RaycastResult hit = result[i];
        if (hit.distance > INF) {
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            break;
        }

        // implement plane rendering

        const Wall wall = walls[hit.wall_id];

        const float cr = hit.corrected_distance;
        const float world_y = camera.position.y + cr * perspective;
        const float wall_y_bottom = wall.start.y + hit.position * (wall.end.y - wall.start.y);
        const float wall_y_top = wall_y_bottom + wall.height;

        if (!(world_y >= wall_y_bottom && world_y <= wall_y_top)) continue;

        const Texture tex = textures[wall.texture_id];

        float u;
        float v;

        switch (tex.type) {
            case TEXTURE_TYPE_STRETCH:
            u = mix(tex.uv_min.x, tex.uv_max.x, hit.position);
            v = 1.0 - mix(tex.uv_min.y, tex.uv_max.y, (world_y - wall_y_bottom) / wall.height);
            break;
            case TEXTURE_TYPE_TILE:
            const float wall_width = length(wall.end.xyz - wall.start.xyz);
            u = fract(mix(tex.uv_min.x, tex.uv_max.x, hit.position * wall_width));
            v = 1.0 - fract(mix(tex.uv_min.y, tex.uv_max.y, (world_y - wall_y_bottom)));
            break;
        }

        if (tex.flip_v) u = 1.0 - u;
        if (tex.flip_h) v = 1.0 - v;

        vec4 tex_pixel = textureLod(texture_atlas, vec3(u, v, float(tex.atlas_id)), 0.0);
        const float shade = clamp(1 / (0.3 * cr), 0.0, 1.0);

        tex_pixel *= tex.tint;

        tex_pixel.rgb *= shade;

        if (tex_pixel.a < 0.01) continue;

        screen_pixel.rgb += tex_pixel.rgb * tex_pixel.a * (1.0 - screen_pixel.a);
        screen_pixel.a += tex_pixel.a * (1.0 - screen_pixel.a);

        if (screen_pixel.a >= 0.99) {
            break;
        }
    }

    FragColor = screen_pixel;
}
