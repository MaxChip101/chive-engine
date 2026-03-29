const vectors = @import("vectors.zig");
const rl = @import("raylib");

pub const Component = union(enum) {
    sprite_object: struct {
        transform: vectors.Transform,
        sprite: rl.Texture2D,
    },
    camera_object: struct { position: vectors.Vec2, zoom: f32, camera: rl.Camera2D },
    audio_source: struct {
        position: vectors.Vec2,
        audio: rl.Sound,
        looping: bool,
    },
};
