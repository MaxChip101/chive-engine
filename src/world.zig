const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const World = struct {
    walls: std.ArrayList(objects.Wall),

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const walls = std.ArrayList(objects.Wall).init(allocator);
        return .{
            .walls = walls,
        };
    }

    pub fn deinit(self: *Self) void {
        self.walls.deinit();
    }

    pub fn addWall(self: *Self, wall: objects.Wall) !usize {
        const index = self.walls.items.len;
        try self.walls.append(wall);
        return index;
    }
};
