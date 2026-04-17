const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const World = struct {
    components: std.ArrayList(objects.Component),
    walls: std.StringHashMap(objects.Wall),

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const components = std.ArrayList(objects.Component).init(allocator);
        const walls = std.StringHashMap(objects.Wall).init(allocator);
        return .{
            .components = components,
            .walls = walls,
        };
    }

    pub fn deinit(self: *Self) void {
        self.components.deinit();
        self.walls.deinit();
    }

    pub fn addComponent(self: *Self, component: objects.Component) !void {
        try self.components.append(component);
    }

    pub fn addWall(self: *Self, id: []u8, wall: objects.Wall) !void {
        try self.walls.put(id, wall);
    }
};
