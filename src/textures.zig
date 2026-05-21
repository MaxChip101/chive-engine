const vectors = @import("vectors.zig");

const gl = @import("zgl");

pub const Texture = struct {
    uv_min: vectors.Vec2,
    uv_max: vectors.Vec2,
    altas_id: u32,
};
