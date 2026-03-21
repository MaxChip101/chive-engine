const vectors = @import("vectors.zig");
const items = @import("items.zig");

pub const Player = struct {
    name: []u8, //
    id: []u8,
    transform: vectors.Transform,
    hotbar: []items.Item,
    slot: u8,
};
