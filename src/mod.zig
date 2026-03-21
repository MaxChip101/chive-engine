pub const Pack = struct {
    name: []u8, //
    version: []u8,
    dependencies: []Dependency,
    entryPoint: EntryPoint,
    source: []u8,
};

pub const Dependency = struct {
    name: []u8, //
    version: []u8,
};

pub const EntryPoint = struct {
    server: []u8, //
    client: []u8,
};
