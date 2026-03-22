pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const Transform = struct {
    position: Vec2,
    scale: Vec2,
    rotation: f32,
};
