const vectors = @import("vectors.zig");
const rl = @import("raylib");

pub const ComponentType = enum {
    sprite_object,
    audio_source,
};

pub const Component = union(ComponentType) {
    sprite_object: struct {
        transform: vectors.Transform,
        sprite: rl.Texture2D,
    },
    audio_source: struct {
        position: vectors.Vec2,
        audio: rl.Sound,
        looping: bool,
    },
};
