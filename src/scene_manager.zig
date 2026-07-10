const std = @import("std");
const mem = std.mem;
const object_manager = @import("object_manager.zig");

pub const Scene = struct {
    loaded_objects: std.AutoArrayHashMap(u32, void),

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const loaded_objects: std.AutoArrayHashMap(u32, void) = .init(allocator);

        return .{
            .loaded_objects = loaded_objects,
        };
    }

    pub fn deinit(self: *Self) void {
        self.loaded_objects.deinit();
    }

    pub fn unloadObject(self: *Self, object_id: u32) bool {
        return self.*.loaded_objects.swapRemove(object_id);
    }

    pub fn loadObject(self: *Self, object_id: u32) !void {
        try self.loaded_objects.put(object_id, {});
    }
};
