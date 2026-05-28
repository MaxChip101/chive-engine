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
uniform uint surface_count;
uniform uint max_surfaces;
uniform uint render_scale;

float width = float(screen_width);
float height = float(screen_height);

out vec4 FragColor;

// implement the result array buffer here so that the raycasts can scale with the max wall variable

vec3 direction_from_pixel(float x, float y) {
    float direction_x = (x - width / 2.0) / camera.projection_distance;
    float direction_y = (y - height / 2.0) / camera.projection_distance;

    float pitch_cos = cos(camera.rotation.x);
    float pitch_sin = sin(camera.rotation.x);
    float yaw_cos = cos(camera.rotation.y);
    float yaw_sin = sin(camera.rotation.y);

    vec3 forward = normalize(vec3(yaw_sin * pitch_cos, pitch_sin, pitch_cos * yaw_cos));
    vec3 right = normalize(vec3(yaw_cos, 0.0, -yaw_sin));
    vec3 up = normalize(vec3(-yaw_sin * pitch_sin, pitch_cos, -yaw_cos * pitch_sin));

    return normalize(forward + right * (direction_x) + up * (direction_y));
}

// dot(uv_vec, right) / length(right) = u coord

float ray(vec3 direction) {
    float nearest = INF;
    float surface_sin;
    float surface_cos;
    for (uint i = 0; i < surface_count; i++) {
        Surface surface = surfaces[i];
        const float denominator = dot(surface.normal, direction);
        if (abs(denominator) < 0.0) continue;
        const float dist = dot(surface.position - camera.position, surface.normal) / denominator;
        vec3 reference = (abs(surface.normal.x) >= 1.0) ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
        vec3 right = normalize(cross(reference, surface.normal));
        vec3 up = normalize(cross(surface.normal, right));
        vec3 uv_vec = camera.position + dist * direction - surface.position;
        float u = dot(uv_vec, right) / length(right);
        float v = dot(uv_vec, up) / length(up);
        if (abs(u) > surface.size.x || abs(v) > surface.size.y) continue;
        if (dist > 0.0 && dist < nearest) nearest = dist;
    }
    return nearest;
}

void main() {
    const float x = gl_FragCoord.x / float(render_scale);
    const float y = gl_FragCoord.y / float(render_scale);

    const vec3 camera_direction = normalize(vec3(sin(camera.rotation.x) * cos(camera.rotation.y), sin(camera.rotation.y), cos(camera.rotation.x) * cos(camera.rotation.y)));

    const vec3 direction = direction_from_pixel(x, y);
    float dist = ray(direction);

    float shade = 1.0 / (0.4 * dist);

    if (dist < INF) {
        FragColor = vec4(shade, shade, shade, 1.0);
    } else {
        FragColor = background;
    }
}
/*
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
*/

/*
#version 450 core

const float INF = 1e10;

struct Wall {
    vec3 start;
    float height;
    vec3 end;
    uint texture_id;
};

struct Plane {
    vec2 start;
    vec2 end;
    float vertical;
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
    float corrected_distance;
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

layout(std430, binding = 4) writeonly buffer PlaneBuffer {
    Plane planes[];
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// plane rendering might just be this but rotated on an angle of sorts

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
        result[result_pos].corrected_distance = distance * cos(camera.rotation.y - angle);
    }
}
*/
