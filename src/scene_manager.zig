const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const Scene = struct {
    surfaces: std.AutoArrayHashMap(u32, objects.Surface),
    next_id: u32,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const surfaces: std.AutoArrayHashMap(u32, objects.Surface) = .init(allocator);
        return .{
            .surfaces = surfaces,
            .next_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.surfaces.deinit();
    }

    pub fn removeSurface(self: *Self, surface_id: u32) bool {
        return self.*.surfaces.swapRemove(surface_id);
    }

    pub fn addSurface(self: *Self, surface: objects.Surface) !u32 {
        const id = self.next_id;
        try self.surfaces.put(id, surface);
        self.*.next_id += 1;
        return id;
    }
};
