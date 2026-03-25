const std = @import("std");
const mem = std.mem;
const fs = std.fs;

pub const Game = struct {
    allocator: mem.Allocator,
    binary_path: []u8,
    binary_directory: []const u8,

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
    // TODO: fix the const string and variable string issue
    pub fn path_from_binary(self: *Self, file: []const u8) ![]u8 {
        return try fs.path.join(self.allocator, &[_][]const u8{ self.binary_directory, file });
    }

    pub fn path_from_binaryZ(self: *Self, file: []const u8) ![:0]const u8 {
        return try fs.path.joinZ(self.allocator, &[_][]const u8{ self.binary_directory, file });
    }

    pub fn read_file_from_path(self: *Self, path: []const u8) ![:0]const u8 {
        var file = try fs.openFileAbsolute(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const content = try file.readToEndAlloc(self.allocator, file_size);
        return content;
    }
};
