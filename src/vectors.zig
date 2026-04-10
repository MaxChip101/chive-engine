pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Ray3D = struct {
    origin: Vec3,
    direction: Vec3,
};

pub const Ray2D = struct {
    origin: Vec2,
    direction: f32,
};

pub const Quaternion = struct {
    w: f32,
    x: f32,
    y: f32,
    z: f32,
};

pub const Transform2D = struct {
    position: Vec2,
    scale: Vec2,
    rotation: f32,
};

pub const Transform3D = struct {
    position: Vec3,
    scale: Vec3,
    rotation: Vec3,
    orientation: Quaternion,
};
