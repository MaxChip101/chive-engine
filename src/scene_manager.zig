const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const Scene = struct {
    surfaces: std.ArrayList(objects.Surface),

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const surfaces = std.ArrayList(objects.Surface).init(allocator);
        return .{
            .surfaces = surfaces,
        };
    }

    pub fn deinit(self: *Self) void {
        self.surfaces.deinit();
    }

    pub fn addSurface(self: *Self, surface: objects.Surface) !usize {
        const index = self.surfaces.items.len;
        try self.surfaces.append(surface);
        return index;
    }
};
