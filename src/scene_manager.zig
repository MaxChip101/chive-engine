const std = @import("std");
const mem = std.mem;
const objects = @import("objects.zig");

pub const Scene = struct {
    objects: std.AutoArrayHashMap(u32, objects.Object),
    surfaces: std.AutoArrayHashMap(u32, objects.Surface),
    billboards: std.AutoArrayHashMap(u32, objects.Billboard),

    next_surface_id: u32,
    next_billboard_id: u32,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const surfaces: std.AutoArrayHashMap(u32, objects.Surface) = .init(allocator);
        const billboards: std.AutoArrayHashMap(u32, objects.Billboard) = .init(allocator);

        return .{
            .surfaces = surfaces,
            .billboards = billboards,
            .next_surface_id = 0,
            .next_billboard_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.surfaces.deinit();
        self.billboards.deinit();
    }

    pub fn removeSurface(self: *Self, surface_id: u32) bool {
        return self.*.surfaces.swapRemove(surface_id);
    }

    pub fn addSurface(self: *Self, surface: objects.Surface) !u32 {
        const id = self.next_surface_id;
        try self.surfaces.put(id, surface);
        self.*.next_surface_id += 1;
        return id;
    }

    pub fn removeBillboard(self: *Self, billboard_id: u32) bool {
        return self.*.surfaces.swapRemove(billboard_id);
    }

    pub fn addBillboard(self: *Self, billboard: objects.Billboard) !u32 {
        const id = self.next_billboard_id;
        try self.surfaces.put(id, billboard);
        self.*.next_billboard_id += 1;
        return id;
    }
};
