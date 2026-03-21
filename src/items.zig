pub const Item = struct {
    displayName: []u8, //
    name: []u8,
    mod: []u8,
    id: []u8,
    data: []Data,
};

pub const DataValue = union(enum) {
    int: i32, //
    float: f32,
    string: []const u8,
    boolean: bool,
};

pub const Data = struct {
    name: []u8, //
    type: []u8,
    data: DataValue,
};
