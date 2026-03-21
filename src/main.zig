const std = @import("std");
const heap = std.heap;

const rl = @import("raylib");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const screenWidth = 800;
    const screenHeight = 600;

    rl.setConfigFlags(.{ .window_resizable = true, .vsync_hint = true });
    rl.initWindow(screenWidth, screenHeight, "mod game");
    rl.setWindowMinSize(480, 360);
    defer rl.closeWindow();

    const currentMonitor = rl.getCurrentMonitor();
    const currentMonitorRefreshRate = rl.getMonitorRefreshRate(currentMonitor);

    //rl.setTargetFPS(currentMonitorRefreshRate);

    const string = try std.fmt.allocPrintZ(allocator, "screen number: {d}, screen refresh rate: {d}", .{ currentMonitor, currentMonitorRefreshRate });
    defer allocator.free(string);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);

        rl.drawText(string, 190, 200, 20, rl.Color.light_gray);
    }
}
