const std = @import("std");
const mem = std.mem;
const object_manager = @import("objects.zig");

pub const Scene = struct {
    objects: std.AutoArrayHashMap(u32, object_manager.Object),

    next_object_id: u32 = 0,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const objects: std.AutoArrayHashMap(u32, object_manager.Object) = .init(allocator);

        return .{
            .objects = objects,
        };
    }

    pub fn deinit(self: *Self) void {
        self.objects.deinit();
    }

    pub fn removeObject(self: *Self, object_id: u32) bool {
        return self.*.objects.swapRemove(object_id);
    }

    pub fn addObject(self: *Self, object: object_manager.Object) !u32 {
        const id = self.next_object_id;
        try self.objects.put(id, object);
        self.*.next_object_id += 1;
        return id;
    }
};
