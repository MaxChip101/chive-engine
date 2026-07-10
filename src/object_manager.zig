const std = @import("std");
const math = std.math;

const vectors = @import("vectors.zig");

pub const TextureType = enum(u32) {
    Stretch = 0,
    Tile = 1,
};

pub const Texture = extern struct {
    uv_min: vectors.Vec2,
    uv_max: vectors.Vec2,
    tex_type: TextureType,
    atlas_id: u32,
    tex_size: vectors.Vec2,
    tint: vectors.Color,
    _pad: [2]f32 = .{ 0, 0 },
};

pub const Billboard = extern struct {
    position: vectors.Vec3,
    rotation: f32,
    lock_axis: vectors.Vec3,
    texture_id: u32,
    size: vectors.Vec2,
    _pad: [2]f32 = .{ 0.0, 0.0 },

    const Self = @This();

    pub fn init(position: vectors.Vec3, rotation: f32, size: vectors.Vec2, lock_axis: vectors.Vec3, texture_id: u32) Self {
        const rad_rotation = math.degreesToRadians(rotation);

        return .{
            .position = position,
            .rotation = rad_rotation,
            .lock_axis = lock_axis,
            .texture_id = texture_id,
            .size = size,
        };
    }

    pub fn setRotation(self: *Self, rotation: f32) void {
        self.*.rotation = math.degreesToRadians(rotation);
    }

    pub fn getRotation(self: Self) f32 {
        return math.radiansToDegrees(self.rotation);
    }
};

pub const Surface = extern struct {
    position: vectors.Vec3,
    rotation: f32,
    normal: vectors.Vec3,
    texture_id: u32,
    size: vectors.Vec2,
    cull_backface: u32, // bool
    _pad: f32 = 0,

    const Self = @This();

    pub fn init(position: vectors.Vec3, normal: vectors.Vec3, rotation: f32, size: vectors.Vec2, cull_backface: bool, texture_id: u32) Self {
        const rad_rotation = math.degreesToRadians(rotation);
        // const reference = if (@abs(normal.y) >= 1.0) vectors.Vec3.forward else vectors.Vec3.up;
        // const right = reference.cross(normal).unit();
        // const up = normal.cross(right).unit();
        return .{
            .position = position,
            .rotation = rad_rotation,
            .normal = normal.unit(),
            .texture_id = texture_id,
            .cull_backface = @intFromBool(cull_backface),
            .size = size,
        };
    }

    pub fn setRadRotation(self: *Self, rad_rotation: f32) void {
        self.*.rotation = rad_rotation;
    }

    pub fn getRadRotation(self: Self) f32 {
        return self.rotation;
    }

    pub fn setRotation(self: *Self, rotation: f32) void {
        self.*.rotation = math.degreesToRadians(rotation);
    }

    pub fn getRotation(self: Self) f32 {
        return math.radiansToDegrees(self.rotation);
    }
};

pub const Camera = extern struct {
    position: vectors.Vec3,
    fov: f32,
    rotation: vectors.Vec3,
    focal_length: f32,
    //forward: vectors.Vec3,
    //right: vectors.Vec3,
    //_pad0: f32 = 0,
    //up: vectors.Vec3,
    //_pad1: f32 = 0,

    var stored_width: u32 = 0;

    const Self = @This();

    pub fn init(position: vectors.Vec3, rotation: vectors.Vec3, fov: f32) Self {
        const rad_fov = math.degreesToRadians(fov);
        // implement the directions
        //const reference = if (@abs(normal.y) >= 1.0) vectors.Vec3.forward else vectors.Vec3.up;
        //const forward =
        //const right = reference.cross(normal).unit();
        //const up = normal.cross(right).unit();
        return .{
            .position = position,
            .fov = rad_fov,
            .rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) },
            .focal_length = 0.0,
        };
    }

    pub fn setFov(self: *Self, fov: f32) void {
        self.*.fov = math.degreesToRadians(fov);
        self.*.updateFocalLength(stored_width);
    }

    pub fn setRadFov(self: *Self, rad_fov: f32) void {
        self.*.fov = rad_fov;
        self.*.updateFocalLength(stored_width);
    }

    pub fn setRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) };
    }

    pub fn getRotation(self: Self) vectors.Vec3 {
        return .{ .x = math.radiansToDegrees(self.rotation.x), .y = math.radiansToDegrees(self.rotation.y), .z = math.radiansToDegrees(self.rotation.z) };
    }

    pub fn setRadRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) };
    }

    pub fn getRadRotation(self: Self) vectors.Vec3 {
        return .{ .x = math.radiansToDegrees(self.rotation.x), .y = math.radiansToDegrees(self.rotation.y), .z = math.radiansToDegrees(self.rotation.z) };
    }

    pub fn getFov(self: Self) f32 {
        return math.radiansToDegrees(self.fov);
    }

    pub fn updateFocalLength(self: *Self, width: u32) void {
        stored_width = width;
        self.*.focal_length = @as(f32, @floatFromInt(width)) / (2 * math.tan(self.fov / 2.0));
    }
};

pub const Object = extern struct {
    position: vectors.Vec3,
    prefab_id: u32,
    rotation: vectors.Vec3,
    _pad0: f32 = 0.0,
    scale: vectors.Vec3,
    _pad1: f32 = 0.0,

    const Self = @This();

    pub fn init(prefab_id: u32, position: vectors.Vec3, rotation: vectors.Vec3, scale: vectors.Vec3) Self {
        return .{
            .position = position,
            .rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) },
            .scale = scale,
            .prefab_id = prefab_id,
        };
    }

    pub fn setRotation(self: *Self, rotation: vectors.Vec3) void {
        self.*.rotation = vectors.Vec3{ .x = math.degreesToRadians(rotation.x), .y = math.degreesToRadians(rotation.y), .z = math.degreesToRadians(rotation.z) };
    }

    pub fn getRotation(self: Self) vectors.Vec3 {
        return .{ .x = math.radiansToDegrees(self.rotation.x), .y = math.radiansToDegrees(self.rotation.y), .z = math.radiansToDegrees(self.rotation.z) };
    }
};

pub const Prefab = extern struct {
    surface_start: u32,
    surface_length: u32,
    billboard_start: u32,
    billboard_length: u32,
    //_pad: [2]f32 = .{ 0.0, 0.0 },
    // colliders, etc
};

// later use quaternions instead of euler

// colliders with feedback calls
// physics that works with colliders
// ui implementation
// make 3d renderer not limited to the screen but can render onto ui elements for minimaps or cameras
