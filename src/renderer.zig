const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const math = std.math;
const glfw = @import("glfw");
const gl = @import("zgl");

const objects = @import("objects.zig");
const world = @import("world.zig");
const physics = @import("physics.zig");
const vectors = @import("vectors.zig");

pub const Renderer = struct {
    width: u32, // either switch to aspect ratio or remove because window stores the width
    height: u32,
    allocator: mem.Allocator,

    window: glfw.Window,

    fragmentShader: gl.Shader,
    vertexShader: gl.Shader,
    shaderProgram: gl.Program,
    computeShader: gl.Shader,
    computeProgram: gl.Program,
    VAO: gl.VertexArray,
    VBO: gl.Buffer,
    raycast_results: std.ArrayList(physics.RayCastResult),
    wallSSBO: gl.Buffer,
    cameraSSBO: gl.Buffer,
    resultsSSBO: gl.Buffer,
    result_buffer: []physics.RayCastResult,
    max_walls: u16,

    const Self = @This();

    const max_compute_x_groups = 64;

    const vertexShaderSource = @embedFile("shaders/vertex.glsl");

    const fragmentShaderSource = @embedFile("shaders/fragment.glsl");

    const computeShaderSource = @embedFile("shaders/compute.glsl");

    pub fn init(allocator: mem.Allocator, width: u32, height: u32, name: []const u8) !Self {
        var self: Self = undefined;
        self.max_walls = 16;
        if (!glfw.init(.{})) {
            return error.GLFWInitFailed;
        }

        const name_c = try allocator.dupeZ(u8, name);
        defer allocator.free(name_c);

        const window = glfw.Window.create(width, height, name_c, null, null, .{
            .opengl_profile = .opengl_core_profile,
            .context_version_major = 4,
            .context_version_minor = 5,
        }) orelse {
            return error.GLFWWindowCreateFailed;
        };

        glfw.makeContextCurrent(window);
        glfw.Window.setFramebufferSizeCallback(window, framebuffer_size_callback);

        const proc: glfw.GLProc = undefined;
        gl.binding.load(proc, glGetProcAddress) catch |err| {
            if (err == error.EntryPointNotFound) {
                std.log.warn("Entry Point Not Found", .{});
            } else {
                return err;
            }
        };

        const vertexShader = gl.createShader(.vertex);

        gl.shaderSource(vertexShader, 1, &.{vertexShaderSource});
        gl.compileShader(vertexShader);

        var success: c_int = undefined;
        var infoLog: [:0]const u8 = undefined;

        gl.binding.getShaderiv(@intFromEnum(vertexShader), gl.binding.COMPILE_STATUS, &success);

        if (success == 0) {
            infoLog = try gl.getShaderInfoLog(vertexShader, allocator);
            std.log.err("{s}", .{infoLog});
            return error.FailedToMakeVertexShader;
        }

        const fragmentShader = gl.createShader(.fragment);

        gl.shaderSource(fragmentShader, 1, &.{fragmentShaderSource});
        gl.compileShader(fragmentShader);

        gl.binding.getShaderiv(@intFromEnum(fragmentShader), gl.binding.COMPILE_STATUS, &success);

        if (success == 0) {
            infoLog = try gl.getShaderInfoLog(fragmentShader, allocator);
            std.log.err("{s}", .{infoLog});
            return error.FailedToMakeFragmentShader;
        }

        const shaderProgram = gl.createProgram();

        gl.attachShader(shaderProgram, vertexShader);
        gl.attachShader(shaderProgram, fragmentShader);
        gl.linkProgram(shaderProgram);

        gl.binding.getProgramiv(@intFromEnum(shaderProgram), gl.binding.LINK_STATUS, &success);
        if (success == 0) {
            infoLog = try gl.getProgramInfoLog(shaderProgram, allocator);
            std.log.err("{s}", .{infoLog});
            return error.FailedToMakeShaderProgram;
        }

        const computeShader = gl.createShader(.compute);

        gl.shaderSource(computeShader, 1, &.{computeShaderSource});
        gl.compileShader(computeShader);

        gl.binding.getShaderiv(@intFromEnum(computeShader), gl.binding.COMPILE_STATUS, &success);

        if (success == 0) {
            infoLog = try gl.getShaderInfoLog(computeShader, allocator);
            std.log.err("{s}", .{infoLog});
            return error.FailedToMakeComputeShader;
        }

        const computeProgram = gl.createProgram();
        std.debug.print("{any}", .{computeProgram});
        gl.attachShader(computeProgram, computeShader);
        gl.linkProgram(computeProgram);

        gl.binding.getProgramiv(@intFromEnum(computeProgram), gl.binding.LINK_STATUS, &success);
        if (success == 0) {
            infoLog = try gl.getProgramInfoLog(computeProgram, allocator);
            std.log.err("{s}", .{infoLog});
            return error.FailedToMakeComputeProgram;
        }

        var vertices = [_]f32{
            -1.0, 1.0, //
            -1.0, -1.0, //
            1.0, -1.0, //
            //
            1.0, -1.0, //
            1.0, 1.0, //
            -1.0, 1.0, //
        };

        const VBO = gl.genBuffer();
        const VAO = gl.genVertexArray();

        const wallSSBO = gl.genBuffer();
        const cameraSSBO = gl.genBuffer();
        const resultsSSBO = gl.genBuffer();

        gl.bindBuffer(wallSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Wall, &[_]objects.Wall{}, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 0, wallSSBO);

        gl.bindBuffer(cameraSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Camera, &[_]objects.Camera{.{
            .position = .{ .x = 0, .y = 0, .z = 0 },
            .fov = 0,
            .rotation = .{ .x = 0, .y = 0, .z = 0 },
            .projection_distance = 0,
        }}, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 1, cameraSSBO);

        const result_buffer = try allocator.alloc(physics.RayCastResult, width * self.max_walls);

        gl.bindBuffer(resultsSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, physics.RayCastResult, result_buffer, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 2, resultsSSBO);

        gl.bindVertexArray(VAO);
        gl.bindBuffer(VBO, .array_buffer);

        gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

        gl.vertexAttribPointer(0, 2, gl.Type.float, false, 2 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);

        gl.enable(.blend);

        self.allocator = allocator;
        self.width = width;
        self.height = height;
        self.window = window;
        self.fragmentShader = fragmentShader;
        self.vertexShader = vertexShader;
        self.shaderProgram = shaderProgram;
        self.computeShader = computeShader;
        self.computeProgram = computeProgram;
        self.VAO = VAO;
        self.VBO = VBO;
        self.wallSSBO = wallSSBO;
        self.cameraSSBO = cameraSSBO;
        self.resultsSSBO = resultsSSBO;
        self.result_buffer = result_buffer;

        return self;
    }

    pub fn deinit(self: *Self) void {
        gl.deleteShader(self.vertexShader);
        gl.deleteShader(self.fragmentShader);
        gl.deleteProgram(self.shaderProgram);
        gl.deleteShader(self.computeShader);
        gl.deleteProgram(self.computeProgram);
        gl.deleteVertexArray(self.VAO);
        gl.deleteBuffer(self.VBO);
        gl.deleteBuffer(self.wallSSBO);
        gl.deleteBuffer(self.cameraSSBO);
        gl.deleteBuffer(self.resultsSSBO);
        self.allocator.free(self.result_buffer);
        self.window.destroy();
        glfw.terminate();
    }

    // pub fn drawCamera(self: *Self, camera: objects.Camera, game_struct: world.World) void {
    //     for (0..self.width) |n| {
    //         const angle: f32 = camera.rad_rotation.y - math.atan((@as(f32, @floatFromInt(n)) - @as(f32, @floatFromInt(self.width)) / 2.0) / camera.proj_dist);

    //         const result = physics.wall_raycast2D(.create(camera.position.x, camera.position.z), angle, game_struct);

    //         if (result == null) continue;
    //         for (result.?) |collisions| {
    //             const distance = collisions.distance;
    //             const pos = collisions.pos;
    //             const wall = collisions.wall;

    //             if (distance >= math.inf(f32)) continue;

    //             const cr: f32 = @max(0.01, distance * math.cos(camera.rad_rotation.y - angle));
    //             const f_height: f32 = @as(f32, @floatFromInt(self.height));
    //             const wall_height: f32 = @min(@max(1.0, camera.proj_dist / cr), f_height);
    //             //const fade: u8 = @as(u8, @intFromFloat(math.clamp(distance * 20, 0, 255)));
    //             const middle = @as(usize, @intFromFloat(@max(0.0, f_height / 2 - (wall_height / 2))));
    //             const vertical = @as(usize, (@intFromFloat(wall_height * (wall.start.y + pos * (wall.end.y - wall.start.y)))));
    //             // try implementing vertical offsetted walls
    //             // switch to shader implementation
    //             switch (wall.material) {
    //                 .color => |color| {
    //                     for (0..@as(usize, @intFromFloat(wall_height * wall.height))) |y| {
    //                         //if (self.getPixel(n, middle + y + vertical).a == 0) {
    //                         const back_pixel = self.getPixel(n, middle + y + vertical);
    //                         const alpha: f32 = @as(f32, @floatFromInt(color.a)) / 255.0;
    //                         const r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(color.r)) * alpha) + (@as(f32, @floatFromInt(back_pixel.r)) * (1 - alpha))));
    //                         const g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(color.g)) * alpha) + (@as(f32, @floatFromInt(back_pixel.g)) * (1 - alpha))));
    //                         const b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(color.b)) * alpha) + (@as(f32, @floatFromInt(back_pixel.b)) * (1 - alpha))));
    //                         self.setPixel(n, middle + y + vertical, .{ .r = r, .g = g, .b = b, .a = color.a });
    //                         //}
    //                     }
    //                 },
    //                 .gradient => {},
    //             }
    //         }
    //     }
    // }

    pub fn render_update(self: *Self, camera: *objects.Camera) !void {
        const size = self.window.getFramebufferSize();
        if (self.width == size.width and self.height == size.height) return;
        self.*.width = size.width;
        self.*.height = size.height;
        camera.updateProjectionDistance(self.width);
        self.*.result_buffer = try self.allocator.realloc(self.*.result_buffer, self.width * self.max_walls);
        @memset(self.*.result_buffer, .{
            .distance = math.inf(f32),
            .position = 0,
            .wall_id = 0,
            .rotation = 0,
        });

        gl.bindBuffer(self.resultsSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, physics.RayCastResult, self.result_buffer, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 2, self.resultsSSBO);
        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);
    }

    pub fn render(self: *Self, camera: *objects.Camera, world_struct: world.World) !void {
        const walls = world_struct.walls.items;

        try render_update(self, camera);

        gl.bindBuffer(self.wallSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Wall, walls, .dynamic_draw);

        gl.bindBuffer(self.cameraSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Camera, &[_]objects.Camera{camera.*}, .dynamic_draw);

        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);

        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(.{ .color = true, .stencil = false, .depth = false });

        const width_location_compute = gl.getUniformLocation(self.computeProgram, "screen_width");
        const height_location_compute = gl.getUniformLocation(self.computeProgram, "screen_height");
        const wall_count_location_compute = gl.getUniformLocation(self.computeProgram, "wall_count");
        const max_walls_location_compute = gl.getUniformLocation(self.computeProgram, "max_walls");

        gl.useProgram(self.computeProgram);

        gl.uniform1i(width_location_compute, @intCast(self.width));
        gl.uniform1i(height_location_compute, @intCast(self.height));
        gl.uniform1ui(wall_count_location_compute, @intCast(walls.len));
        gl.uniform1ui(max_walls_location_compute, self.max_walls);

        const groups_x = (self.width + (max_compute_x_groups - 1)) / max_compute_x_groups;
        gl.binding.dispatchCompute(groups_x, 1, 1);
        gl.binding.memoryBarrier(gl.binding.SHADER_STORAGE_BARRIER_BIT);

        const width_location_shader = gl.getUniformLocation(self.shaderProgram, "screen_width");
        const height_location_shader = gl.getUniformLocation(self.shaderProgram, "screen_height");
        const max_walls_location_shader = gl.getUniformLocation(self.shaderProgram, "max_walls");

        gl.useProgram(self.shaderProgram);

        gl.uniform1i(width_location_shader, @intCast(self.width));
        gl.uniform1i(height_location_shader, @intCast(self.height));
        gl.uniform1ui(max_walls_location_shader, self.max_walls);

        gl.bindVertexArray(self.VAO);
        gl.drawArrays(.triangles, 0, 6);

        self.window.swapBuffers();
    }

    pub fn update(self: *Self) void {
        _ = self;
        glfw.pollEvents();
    }

    fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
        _ = p;
        return glfw.getProcAddress(proc);
    }

    fn framebuffer_size_callback(window: glfw.Window, width: u32, height: u32) void {
        _ = window;
        gl.viewport(0, 0, @intCast(width), @intCast(height));
    }
};
