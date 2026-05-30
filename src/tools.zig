const std = @import("std");
const mem = std.mem;
const fs = std.fs;

pub fn path_from_binary(allocator: mem.Allocator, path: []const u8) ![]u8 {
    const binary_directory = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(binary_directory);
    return try fs.path.join(allocator, &[_][]const u8{ binary_directory, path });
}

pub fn path_from_binaryZ(allocator: mem.Allocator, path: []const u8) ![:0]const u8 {
    const binary_directory = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(binary_directory);
    return try fs.path.joinZ(allocator, &[_][]const u8{ binary_directory, path });
}

pub fn read_file_from_path(allocator: mem.Allocator, path: []const u8) ![]u8 {
    var file = try fs.openFileAbsolute(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try file.readToEndAlloc(allocator, file_size);
    return content;
}

pub fn read_file_from_pathZ(allocator: mem.Allocator, path: []const u8) ![:0]const u8 {
    var file = try fs.openFileAbsolute(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(content);
    const contentZ = try allocator.dupeZ(u8, content);
    return contentZ;
}
