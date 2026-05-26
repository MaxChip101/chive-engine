const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const World = struct {
    walls: std.ArrayList(objects.Wall),
    planes: std.ArrayList(objects.Plane),

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const walls = std.ArrayList(objects.Wall).init(allocator);
        const planes = std.ArrayList(objects.Plane).init(allocator);
        return .{
            .walls = walls,
            .planes = planes,
        };
    }

    pub fn deinit(self: *Self) void {
        self.walls.deinit();
        self.planes.deinit();
    }

    pub fn addWall(self: *Self, wall: objects.Wall) !usize {
        const index = self.walls.items.len;
        try self.walls.append(wall);
        return index;
    }

    pub fn addPlane(self: *Self, plane: objects.Plane) !usize {
        const index = self.planes.items.len;
        try self.planes.append(plane);
        return index;
    }
};
