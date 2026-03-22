const std = @import("std");
const mem = std.mem;
const fs = std.fs;

pub const Game = struct {
    allocator: mem.Allocator,
    binary_path: []u8,
    binary_directory: []u8,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        const binary_path = try fs.selfExeDirPathAlloc(allocator);
        const binary_directory = fs.path.dirname(binary_path) orelse ".";
        return .{
            .allocator = allocator,
            .binary_path = binary_path,
            .binary_directory = binary_directory,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.binary_path);
    }

    pub fn path_from_binary(self: *Self, file: []u8) ![]u8 {
        try fs.path.join(self.allocator, &[_][]const u8{ self.binary_directory, file });
    }
};
