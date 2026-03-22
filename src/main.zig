const std = @import("std");
const fs = std.fs;
const heap = std.heap;

const rl = @import("raylib");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const exe_path = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_path);
    const exe_dir = fs.path.dirname(exe_path) orelse ".";

    _ = exe_dir;

    const screen_width = 800;
    const screen_height = 600;

    rl.setConfigFlags(.{ .window_resizable = true, .vsync_hint = true });
    rl.initWindow(screen_width, screen_height, "mod game");
    rl.setWindowMinSize(480, 360);
    defer rl.closeWindow();

    const current_monitor = rl.getCurrentMonitor();
    const current_monitor_refresh_rate = rl.getMonitorRefreshRate(current_monitor);

    //rl.setTargetFPS(currentMonitorRefreshRate);

    const string = try std.fmt.allocPrintZ(allocator, "screen number: {d}, screen refresh rate: {d}", .{ current_monitor, current_monitor_refresh_rate });
    defer allocator.free(string);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);

        rl.drawText(string, 190, 200, 20, rl.Color.light_gray);
    }
}
