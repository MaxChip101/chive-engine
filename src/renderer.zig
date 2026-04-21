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
    width: u32,
    height: u32,
    allocator: mem.Allocator,

    window: glfw.Window,

    fragmentShader: gl.Shader,
    vertexShader: gl.Shader,
    shaderProgram: gl.Program,
    computeShader: gl.Shader,
    computeProgram: gl.Program,
    VAO: [1]gl.VertexArray,
    VBO: [1]gl.Buffer,
    SSBO: [1]gl.Buffer,

    const Self = @This();

    const max_compute_x_groups = 64;

    const vertexShaderSource =
        \\  #version 450 core
        \\
        \\  layout(location = 0) in vec2 aPos;
        \\
        \\  void main() {
        \\      gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
        \\  }
    ;

    const fragmentShaderSource =
        \\  #version 450 core
        \\
        \\  layout(std430, binding = 1) buffer HitBuffer {
        \\      Column columns[];
        \\  };
        \\
        \\  out vec4 FragColor;
        \\
        \\  void main() {
        \\      FragColor = vec4(gl_FragCoord.x / 500, 0.2, 1.0, 1.0);
        \\  }
    ;

    const computeShaderSource =
        \\  #version 450 core
        \\  layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
        \\ 
        \\  void main() {
        \\      
        \\  }
    ;

    pub fn init(allocator: mem.Allocator, width: u32, height: u32, name: []const u8) !Self {
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
        std.debug.print("{any}", .{shaderProgram});

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

        var VBO: [1]gl.Buffer = undefined;
        var VAO: [1]gl.VertexArray = undefined;
        var SSBO: [1]gl.Buffer = undefined;

        gl.genVertexArrays(&VAO);

        gl.genBuffers(&VBO);

        gl.genBuffers(&SSBO);

        gl.bindVertexArray(VAO[0]);
        gl.bindBuffer(VBO[0], .array_buffer);

        gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

        gl.vertexAttribPointer(0, 3, gl.Type.float, false, 2 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        gl.bindBufferBase(.shader_storage_buffer, 0, SSBO[0]);

        gl.enable(.blend);

        // enter parameters
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .window = window,
            .fragmentShader = fragmentShader,
            .vertexShader = vertexShader,
            .shaderProgram = shaderProgram,
            .computeShader = computeShader,
            .computeProgram = computeProgram,
            .VAO = VAO,
            .VBO = VBO,
            .SSBO = SSBO,
        };
    }

    pub fn deinit(self: *Self) void {
        gl.deleteShader(self.vertexShader);
        gl.deleteShader(self.fragmentShader);
        gl.deleteProgram(self.shaderProgram);
        gl.deleteShader(self.computeShader);
        gl.deleteProgram(self.computeProgram);
        gl.deleteVertexArrays(&self.VAO);
        gl.deleteBuffers(&self.VBO);
        gl.deleteBuffers(&self.SSBO);
        self.window.destroy();
        glfw.terminate();
    }

    pub fn drawCamera(self: *Self, camera: objects.Camera, game_struct: world.World) void {
        for (0..self.width) |n| {
            const angle: f32 = camera.rad_rotation.y - math.atan((@as(f32, @floatFromInt(n)) - @as(f32, @floatFromInt(self.width)) / 2.0) / camera.proj_dist);

            const result = physics.wall_raycast2D(.create(camera.position.x, camera.position.z), angle, game_struct);

            if (result == null) continue;
            for (result.?) |collisions| {
                const distance = collisions.distance;
                const pos = collisions.pos;
                const wall = collisions.wall;

                if (distance >= math.inf(f32)) continue;

                const cr: f32 = @max(0.01, distance * math.cos(camera.rad_rotation.y - angle));
                const f_height: f32 = @as(f32, @floatFromInt(self.height));
                const wall_height: f32 = @min(@max(1.0, camera.proj_dist / cr), f_height);
                //const fade: u8 = @as(u8, @intFromFloat(math.clamp(distance * 20, 0, 255)));
                const middle = @as(usize, @intFromFloat(@max(0.0, f_height / 2 - (wall_height / 2))));
                const vertical = @as(usize, (@intFromFloat(wall_height * (wall.start.y + pos * (wall.end.y - wall.start.y)))));
                // try implementing vertical offsetted walls
                // switch to shader implementation
                switch (wall.material) {
                    .color => |color| {
                        for (0..@as(usize, @intFromFloat(wall_height * wall.height))) |y| {
                            //if (self.getPixel(n, middle + y + vertical).a == 0) {
                            const back_pixel = self.getPixel(n, middle + y + vertical);
                            const alpha: f32 = @as(f32, @floatFromInt(color.a)) / 255.0;
                            const r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(color.r)) * alpha) + (@as(f32, @floatFromInt(back_pixel.r)) * (1 - alpha))));
                            const g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(color.g)) * alpha) + (@as(f32, @floatFromInt(back_pixel.g)) * (1 - alpha))));
                            const b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(color.b)) * alpha) + (@as(f32, @floatFromInt(back_pixel.b)) * (1 - alpha))));
                            self.setPixel(n, middle + y + vertical, .{ .r = r, .g = g, .b = b, .a = color.a });
                            //}
                        }
                    },
                    .gradient => {},
                }
            }
        }
    }

    pub fn render(self: *Self) void {
        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(.{ .color = true, .stencil = false, .depth = false });

        gl.useProgram(self.computeProgram);
        const groups_x = (self.width + (max_compute_x_groups - 1)) / max_compute_x_groups;
        gl.binding.dispatchCompute(groups_x, 1, 1);
        gl.binding.memoryBarrier(gl.binding.SHADER_STORAGE_BARRIER_BIT);

        gl.useProgram(self.shaderProgram);

        gl.bindVertexArray(self.VAO[0]);
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
