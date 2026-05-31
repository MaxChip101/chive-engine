#version 450 core

const uint MAX_SURFACES = 6;
const float INF = 1e10;
const vec4 background = vec4(0, 0, 0, 0);

const uint TEXTURE_TYPE_STRETCH = 0;
const uint TEXTURE_TYPE_TILE = 1;

struct Texture {
    vec2 uv_min;
    vec2 uv_max;
    uint type;
    uint atlas_id;
    bool flip_u;
    bool flip_v;
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

struct RayResult {
    uint surface_id;
    float distance;
    vec2 uv;
};

struct Camera {
    vec3 position;
    float fov;
    vec3 rotation;
    float focal_length;
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
uniform uint surface_count;
uniform uint resolution_width;
uniform uint resolution_height;

float width = float(screen_width);
float height = float(screen_height);

out vec4 FragColor;

vec3 rotate_vector(vec3 vector, vec3 axis, float angle) {
    return vector * cos(angle) + cross(axis, vector) * sin(angle) + axis * dot(axis, vector) * (1.0 - cos(angle));
}

vec3 direction_from_pixel(float x, float y) {
    float direction_x = (x - width / 2.0) / camera.focal_length;
    float direction_y = (y - height / 2.0) / camera.focal_length;

    float pitch_cos = cos(camera.rotation.x);
    float pitch_sin = sin(camera.rotation.x);
    float yaw_cos = cos(camera.rotation.y);
    float yaw_sin = sin(camera.rotation.y);

    vec3 forward = normalize(vec3(yaw_sin * pitch_cos, pitch_sin, pitch_cos * yaw_cos));
    vec3 right = normalize(vec3(yaw_cos, 0.0, -yaw_sin));
    vec3 up = normalize(vec3(-yaw_sin * pitch_sin, pitch_cos, -yaw_cos * pitch_sin));

    return normalize(forward + right * (direction_x) + up * (direction_y));
}

RayResult[MAX_SURFACES] ray(vec3 direction) {
    float last_nearest = 0;
    RayResult[MAX_SURFACES] results;
    for (uint ray = 0; ray < MAX_SURFACES; ray++) {
        float nearest = INF;
        uint surface_id;
        vec2 uv = vec2(0, 0);
        for (uint id = 0; id < surface_count; id++) {
            Surface surface = surfaces[id];
            const float denominator = dot(surface.normal, direction);
            if (abs(denominator) <= 0.0) continue;
            const float dist = dot(surface.position - camera.position, surface.normal) / denominator;
            vec3 reference = (abs(surface.normal.y) >= 1.0) ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
            vec3 right = normalize(cross(reference, surface.normal));
            vec3 up = normalize(cross(surface.normal, right));
            vec3 rotated_right = rotate_vector(right, surface.normal, surface.rotation);
            vec3 rotated_up = rotate_vector(up, surface.normal, surface.rotation);
            vec3 uv_vec = camera.position + dist * direction - surface.position;
            float u = dot(uv_vec, rotated_right);
            float v = dot(uv_vec, rotated_up);
            if (abs(u) <= surface.size.x && abs(v) <= surface.size.y && 
            dist > 0.0 && dist < nearest && last_nearest < dist) {
                nearest = dist;
                uv = vec2(u, v);
                surface_id = id;
            }
        }
        if (nearest < INF) {
            last_nearest = nearest;
        }
        results[ray].distance = nearest;
        results[ray].uv = uv;
        results[ray].surface_id = surface_id;
    }
    return results;
}

void main() {
    vec2 screen = vec2(screen_width, screen_height);
    vec2 screen_coord = gl_FragCoord.xy - screen / 2.0;
    vec2 rotated_coord = vec2(
        screen_coord.x * cos(-camera.rotation.z) - screen_coord.y * sin(-camera.rotation.z),
        screen_coord.x * sin(-camera.rotation.z) + screen_coord.y * cos(-camera.rotation.z)
    ) + screen / 2.0;


    const float scale_x = screen.x / float(resolution_width);
    const float scale_y = screen.y / float(resolution_height);

    const float x = (floor(rotated_coord.x / scale_x) + 0.5) * scale_x;
    const float y = (floor(rotated_coord.y / scale_y) + 0.5) * scale_y;

    const vec3 direction = direction_from_pixel(x, y);
    RayResult ray_results[MAX_SURFACES] = ray(direction);

    vec4 screen_pixel = background;

    for (uint ray = 0; ray < MAX_SURFACES; ray++) {
        const RayResult result = ray_results[ray];
        if (result.distance >= INF)
            break;

        const Surface surface = surfaces[result.surface_id];

        const Texture tex = textures[surface.texture_id];

        vec2 uv_coord;

        switch (tex.type) {
            case TEXTURE_TYPE_STRETCH:
            uv_coord = vec2(
                1.0 - mix(tex.uv_min.x, tex.uv_max.x, (result.uv.x / surface.size.x) * 0.5 + 0.5),
                1.0 - mix(tex.uv_min.y, tex.uv_max.y, (result.uv.y / surface.size.y) * 0.5 + 0.5)
            );
            break;
            case TEXTURE_TYPE_TILE:
            uv_coord = vec2(
                1.0 - mix(tex.uv_min.x, tex.uv_max.x, result.uv.x / surface.size.x),
                1.0 - mix(tex.uv_min.y, tex.uv_max.y, result.uv.y / surface.size.y)
            );
            break;
        }

        if (tex.flip_u) uv_coord.x = 1.0 - uv_coord.x;
        if (tex.flip_v) uv_coord.y = 1.0 - uv_coord.y;

        vec4 tex_pixel = textureLod(texture_atlas, vec3(uv_coord.x, uv_coord.y, float(tex.atlas_id)), 0.0);
        const float shade = clamp(1 / (0.3 * result.distance), 0.0, 1.0);

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
