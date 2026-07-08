#version 450 core

const uint RAY_PIXEL_DEPTH = 4;
const uint SKYBOX_PIXEL_DEPTH = 1;
const uint MAX_PIXEL_DEPTH = RAY_PIXEL_DEPTH + SKYBOX_PIXEL_DEPTH;

const float INF = 1e10;
const vec4 background = vec4(0, 0, 0, 0);

const uint TEXTURE_TYPE_STRETCH = 0;
const uint TEXTURE_TYPE_TILE = 1;

const uint RAY_TYPE_BILLBOARD = 0;
const uint RAY_TYPE_SURFACE = 1;
const uint RAY_TYPE_SKYBOX = 2;

struct Texture {
    vec2 uv_min;
    vec2 uv_max;
    uint type;
    uint atlas_id;
    vec2 size;
    vec4 tint;
    float _pad[2];
};

struct Surface {
    vec3 position;
    float rotation;
    vec3 normal;
    uint texture_id;
    vec2 size;
    uint cull_backface;
    float _pad;
};

struct Billboard {
    vec3 position;
    float rotation;
    vec3 lock_axis;
    uint texture_id;
    vec2 size;
    float _pad;
};

// impl use local axis
// cache some things by calculating it on the gpu like:
// rotation matrix
// basis matrix
// etc


struct RayResult {
    uint id;
    float distance;
    vec2 uv;
    uint type;
    vec2 world_size;
};

struct RayCheck {
    vec2 uv;
    float distance;
    bool successful;
};

struct Camera {
    vec3 position;
    float fov;
    vec3 rotation;
    float focal_length;
};

struct Prefab {
    uint surface_start;
    uint surface_length;
    uint billboard_start;
    uint billboard_length;
};

struct Object {
    vec3 position;
    uint prefab_id;
    vec3 rotation;
    float _pad0;
    vec3 scale;
    float _pad1;
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

layout(std430, binding = 3) readonly buffer BillboardBuffer {
    Billboard billboards[];
};

layout(std430, binding = 4) readonly buffer PrefabBuffer {
    Prefab prefabs[];
};

layout(std430, binding = 5) readonly buffer ObjectBuffer {
    Object objects[];
};

uniform sampler2DArray texture_atlas;

uniform int screen_width;
uniform int screen_height;
uniform uint surface_count;
uniform uint billboard_count;
uniform uint prefab_count;
uniform uint object_count;
uniform uint resolution_width;
uniform uint resolution_height;

float width = float(screen_width);
float height = float(screen_height);

out vec4 FragColor;

mat3 rotation_matrix(vec3 euler) {
    float cx = cos(-euler.x);
    float sx = sin(-euler.x);
    float cy = cos(euler.y);
    float sy = sin(euler.y);
    float cz = cos(-euler.z);
    float sz = sin(-euler.z);

    return mat3(
        cy * cz,
        cy * sz,
        -sy,

        sx * sy * cz - cx * sz,
        sx * sy * sz + cx * cz,
        sx * cy,

        cx * sy * cz + sx * sz,
        cx * sy * sz - sx * cz,
        cx * cy
    );
}

mat3 basis_from_normal(vec3 normal, float rotation) {
    vec3 reference = (abs(normal.y) >= 1.0) ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(reference, normal));
    vec3 up = normalize(cross(normal, right));

    mat3 frame = mat3(right, up, normal);
    float c = cos(rotation);
    float s = sin(rotation);
    mat3 rz = mat3(c, s, 0, -s, c, 0, 0, 0, 1);

    return frame * rz;
}

vec3 direction_from_pixel(vec2 pixel) {
    float inverse_focal = 1.0 / camera.focal_length;
    float direction_x = (pixel.x - (width * 0.5)) * inverse_focal;
    float direction_y = (pixel.y - (height * 0.5)) * inverse_focal;

    vec3 base_ray = vec3(direction_x, direction_y, 1.0);

    mat3 camera_matrix = rotation_matrix(camera.rotation);

    return normalize(camera_matrix * base_ray);
}

RayCheck ray_check(vec3 position, mat3 orientation, vec3 ray_direction, vec2 size) {
    RayCheck check;
    check.successful = false;
    vec3 normal = orientation[2];
    const float denominator = dot(normal, ray_direction);
    if (abs(denominator) <= 0.0) return check;
    const float distance = dot(position - camera.position, normal) / denominator;
    vec3 uv_vec = camera.position + distance * ray_direction - position;
    vec2 uv = vec2(dot(uv_vec, orientation[0]), dot(uv_vec, orientation[1]));
    if (abs(uv.x) <= size.x && abs(uv.y) <= size.y) {
        check.uv = uv;
        check.distance = distance;
        check.successful = true;
    }
    return check;
}

RayResult[MAX_PIXEL_DEPTH] ray(vec3 ray_direction) {
    float last_nearest = 0;
    RayResult[MAX_PIXEL_DEPTH] results;
    for (uint ray = 0; ray < RAY_PIXEL_DEPTH; ray++) {
        float nearest = INF;
        uint id;
        uint type;
        vec2 uv = vec2(-1, -1);
        vec2 world_size = vec2(0, 0);

        for (uint object_id = 0; object_id < object_count; object_id++) {

            Object object = objects[object_id];
            Prefab prefab = prefabs[object.prefab_id];

            mat3 object_rotation = rotation_matrix(object.rotation);

            if (prefab.billboard_length != 0) {
                for (uint billboard_id = prefab.billboard_start; billboard_id < prefab.billboard_start + prefab.billboard_length; billboard_id++) {
                    Billboard billboard = billboards[billboard_id];
                    vec3 normalized_position = object.position + object_rotation * (billboard.position * object.scale);
                    vec3 direction = normalize(camera.position - normalized_position);
                    vec3 lock_axis = billboard.lock_axis;
                    if (lock_axis != vec3(0, 0, 0)) {
                        lock_axis = normalize(object_rotation * lock_axis);
                        direction = normalize(direction - dot(direction, lock_axis) * lock_axis);
                    }
                    

                    mat3 world_orientation = basis_from_normal(direction, billboard.rotation);

                    vec2 size = vec2(billboard.size.x * length(object.scale * world_orientation[0]), billboard.size.y * length(object.scale * world_orientation[1])) * 0.5;

                    RayCheck check = ray_check(normalized_position, world_orientation, ray_direction, size);

                    if (check.successful && check.distance > 0.0 && check.distance < nearest && last_nearest < check.distance) {
                        id = billboard_id;
                        nearest = check.distance;
                        uv = check.uv;
                        type = RAY_TYPE_BILLBOARD;
                        world_size = size;
                    }
                }
            }

            if (prefab.surface_length != 0) {
                for (uint surface_id = prefab.surface_start; surface_id < prefab.surface_start + prefab.surface_length; surface_id++) {
                    Surface surface = surfaces[surface_id];
                    if (surface.cull_backface == 1 && dot(surface.normal, ray_direction) >= 0) continue;
                    vec3 normalized_position = object.position + object_rotation * (surface.position * object.scale);
                    mat3 local_orientation = basis_from_normal(surface.normal, surface.rotation);
                    mat3 world_orientation = object_rotation * local_orientation;
                    vec2 size = vec2(surface.size.x * length(object.scale * local_orientation[0]), surface.size.y * length(object.scale * local_orientation[1])) * 0.5;

                    RayCheck check = ray_check(normalized_position, world_orientation, ray_direction, size);

                    if (check.successful && check.distance > 0.0 && check.distance < nearest && last_nearest < check.distance) {
                        id = surface_id;
                        nearest = check.distance;
                        uv = check.uv;
                        type = RAY_TYPE_SURFACE;
                        world_size = size;
                    }
                }
            }
        }
        if (nearest < INF) {
            last_nearest = nearest;
        }
        results[ray].distance = nearest;
        results[ray].uv = uv;
        results[ray].id = id;
        results[ray].type = type;
        results[ray].world_size = world_size;
    }
    return results;
}

void main() {
    const vec2 screen = vec2(screen_width, screen_height);
    const vec2 resolution = vec2(resolution_width, resolution_height);

    const vec2 scale = screen / resolution;
    const vec2 pos = (floor(gl_FragCoord.xy / scale) + 0.5) * scale;

    const vec3 direction = direction_from_pixel(pos);
    RayResult ray_results[MAX_PIXEL_DEPTH] = ray(direction);

    vec4 screen_pixel = background;

    for (uint ray = 0; ray < MAX_PIXEL_DEPTH; ray++) {
        const RayResult result = ray_results[ray];
        if (result.distance >= INF)
            break;

        Texture tex = textures[0];

        switch (result.type) {
            case RAY_TYPE_BILLBOARD:
            Billboard billboard = billboards[result.id];
            tex = textures[billboard.texture_id];
            break;
            case RAY_TYPE_SURFACE:
            Surface surface = surfaces[result.id];
            tex = textures[surface.texture_id];
            break;
            case RAY_TYPE_SKYBOX:
            tex = textures[0];
            // impl later
            break;
        }

        vec2 uv_coord;

        switch (tex.type) {
            case TEXTURE_TYPE_STRETCH:
            uv_coord = vec2(
                    1.0 - mix(tex.uv_min.x, tex.uv_max.x, (result.uv.x / result.world_size.x) * 0.5 + 0.5),
                    mix(tex.uv_min.y, tex.uv_max.y, (result.uv.y / result.world_size.y) * 0.5 + 0.5)
                );
            break;
            case TEXTURE_TYPE_TILE:
            uv_coord = vec2(
                    1.0 - mix(tex.uv_min.x, tex.uv_max.x, result.uv.x / result.world_size.x),
                    mix(tex.uv_min.y, tex.uv_max.y, result.uv.y / result.world_size.y)
                );
            break;
        }

        vec4 tex_pixel = textureLod(texture_atlas, vec3(uv_coord.x, uv_coord.y, float(tex.atlas_id)), 0.0);
        const float shade = clamp(1 / (0.3 * result.distance), 0.1, 1.0);

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
