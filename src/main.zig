const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const math = std.math;

const zlua = @import("zlua");
const game = @import("game.zig");
const renderer = @import("renderer.zig");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const screen_width = 800;
    const screen_height = 600;

    var renderer_struct: renderer.Renderer = try .init(allocator, screen_width, screen_height);
    defer renderer_struct.deinit();

    var game_struct: game.Game = try .init(allocator);
    defer game_struct.deinit();

    const cam_x: f32 = 0.0;
    const cam_y: f32 = 8.0;

    const wall_y1: f32 = 10;
    const wall_x1: f32 = 0;
    const wall_x2: f32 = 2;
    const wall_y2: f32 = 10;

    const angle_origin: f32 = math.degreesToRadians(70.0);
    const fov: f32 = math.degreesToRadians(90.0);

    const proj_dist: f32 = (@as(f32, @floatFromInt(screen_width)) / 2.0) / math.tan(fov / 2.0);

    const half_height: u32 = @as(u32, @intCast(screen_height / 2));

    for (0..screen_width) |n| {
        const angle: f32 = angle_origin - math.atan((@as(f32, @floatFromInt(n)) - @as(f32, @floatFromInt(screen_width)) / 2.0) / proj_dist);
        //const angle: f32 = angle_origin - math.atan(@as(f32, @floatFromInt(n)) / proj_dist);
        const ray_x = cam_x + math.cos(angle);
        const ray_y = cam_y + math.sin(angle);

        const den: f32 = (wall_x1 - wall_x2) * (cam_y - ray_y) - (wall_y1 - wall_y2) * (cam_x - ray_x);

        if (den == 0.0) continue;

        const t: f32 = ((wall_x1 - cam_x) * (cam_y - ray_y) - (wall_y1 - cam_y) * (cam_x - ray_x)) / den;
        const u: f32 = -((wall_x1 - wall_x2) * (wall_y1 - cam_y) - (wall_y1 - wall_y2) * (wall_x1 - cam_x)) / den;

        if (!(t > 0.0 and t < 1.0 and u > 0.0)) continue;

        //const rx: f32 = wall_x1 + t * (wall_x2 - wall_x1);
        //const ry: f32 = wall_y1 + t * (wall_y2 - wall_y1);

        //const r: f32 = math.sqrt((rx - cam_x) * (rx - cam_x) + (ry - cam_y) * (ry - cam_y));

        const cr: f32 = u * math.cos(angle_origin - angle);
        const wall_height: u32 = @min(@as(u32, @intFromFloat(@max(1.0, proj_dist / cr))), screen_height);

        for (0..@as(usize, @intCast(wall_height))) |y| {
            renderer_struct.setPixel(n, @max(0, half_height - (@divTrunc(wall_height, 2)) + y), 255, 255, 255, 255);
        }
    }

    const script_path = try game_struct.path_from_binaryZ("../test.lua");

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();
    lua.doFile(script_path) catch |err| {
        std.debug.print("{any}", .{err});
    };
    while (!renderer_struct.window.shouldClose()) {
        renderer_struct.render();
    }
}
