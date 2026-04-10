const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const World = struct {
    components: std.ArrayList(objects.Component),

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const components = std.ArrayList(objects.Component).init(allocator);
        return .{ .components = components };
    }

    pub fn deinit(self: *Self) void {
        self.components.deinit();
    }

    pub fn addComponent(self: *Self, component: objects.Component) void {
        try self.components.append(component);
    }
};
