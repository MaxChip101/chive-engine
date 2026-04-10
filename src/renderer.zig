const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const math = std.math;
const glfw = @import("glfw");
const gl = @import("zgl");

const objects = @import("objects.zig");
const world = @import("world.zig");
const physics = @import("physics.zig");

pub const Renderer = struct {
    width: u32,
    height: u32,
    allocator: mem.Allocator,

    window: glfw.Window,
    texture: gl.Texture,
    pixels: []u8,

    fragmentShader: gl.Shader,
    vertexShader: gl.Shader,
    shaderProgram: gl.Program,
    VAO: [1]gl.VertexArray,
    VBO: [1]gl.Buffer,
    EBO: [1]gl.Buffer,

    const Self = @This();

    const vertexShaderSource =
        \\ #version 410 core
        \\ layout (location = 0) in vec3 aPos;
        \\ layout (location = 1) in vec2 aTexCoord;
        \\ out vec2 TexCoord;
        \\ void main()
        \\ {
        \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        \\   TexCoord = aTexCoord;
        \\ }
    ;

    const fragmentShaderSource =
        \\ #version 410 core
        \\ in vec2 TexCoord;
        \\ out vec4 FragColor;
        \\ uniform sampler2D pixelBuffer;
        \\ void main() {
        \\   FragColor = texture(pixelBuffer, TexCoord);
        \\ }
    ;

    pub fn init(allocator: mem.Allocator, width: u32, height: u32) !Self {
        if (!glfw.init(.{})) {
            return error.GLFWInitFailed;
        }

        const window = glfw.Window.create(width, height, "mod game", null, null, .{
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
        }

        const fragmentShader = gl.createShader(.fragment);

        gl.shaderSource(fragmentShader, 1, &.{fragmentShaderSource});
        gl.compileShader(fragmentShader);

        gl.binding.getShaderiv(@intFromEnum(fragmentShader), gl.binding.COMPILE_STATUS, &success);

        if (success == 0) {
            infoLog = try gl.getShaderInfoLog(fragmentShader, allocator);
            std.log.err("{s}", .{infoLog});
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
        }

        var vertices = [_]f32{
            // positions        // texture coords
            -1.0, 1.0, 0.0, 0.0, 1.0, // top left
            -1.0, -1.0, 0.0, 0.0, 0.0, // bottom left
            1.0, -1.0, 0.0, 1.0, 0.0, // bottom right
            1.0, 1.0, 0.0, 1.0, 1.0, // top right
        };

        var indices = [_]u32{ 0, 1, 2, 0, 2, 3 };

        var VBO: [1]gl.Buffer = undefined;
        var VAO: [1]gl.VertexArray = undefined;
        var EBO: [1]gl.Buffer = undefined;

        gl.genVertexArrays(&VAO);

        gl.genBuffers(&VBO);

        gl.genBuffers(&EBO);

        gl.bindVertexArray(VAO[0]);
        gl.bindBuffer(VBO[0], .array_buffer);

        gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

        gl.bindBuffer(EBO[0], .element_array_buffer);
        gl.bufferData(gl.BufferTarget.element_array_buffer, u32, &indices, gl.BufferUsage.static_draw);

        gl.vertexAttribPointer(0, 3, gl.Type.float, false, 5 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        gl.vertexAttribPointer(1, 2, gl.Type.float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
        gl.enableVertexAttribArray(1);

        const pixels = try allocator.alloc(u8, width * height * 4);
        @memset(pixels, 0);

        const texture = gl.Texture.gen();
        gl.bindTexture(texture, .@"2d");

        gl.textureImage2D(
            .@"2d",
            0,
            .rgba,
            width,
            height,
            .rgba,
            .unsigned_byte,
            pixels.ptr,
        );

        gl.texParameter(.@"2d", .min_filter, .nearest);
        gl.texParameter(.@"2d", .mag_filter, .nearest);

        // enter parameters
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .window = window,
            .texture = texture,
            .pixels = pixels,
            .fragmentShader = fragmentShader,
            .vertexShader = vertexShader,
            .shaderProgram = shaderProgram,
            .VAO = VAO,
            .VBO = VBO,
            .EBO = EBO,
        };
    }

    pub fn deinit(self: *Self) void {
        gl.deleteShader(self.vertexShader);
        gl.deleteShader(self.fragmentShader);
        gl.deleteProgram(self.shaderProgram);
        gl.deleteVertexArrays(&self.VAO);
        gl.deleteBuffers(&self.VBO);
        gl.deleteBuffers(&self.EBO);
        self.allocator.free(self.pixels);
        self.window.destroy();
        glfw.terminate();
    }

    pub fn setPixel(self: *Self, x: usize, y: usize, r: u8, g: u8, b: u8, a: u8) void {
        if (x >= self.width or y >= self.height) return;

        const index = (y * self.width + x) * 4;

        self.*.pixels[index] = r;
        self.*.pixels[index + 1] = g;
        self.*.pixels[index + 2] = b;
        self.*.pixels[index + 3] = a;
    }

    pub fn drawCamera(self: *Self, camera: objects.Camera, game_struct: world.World) void {
        for (0..self.width) |n| {
            const angle: f32 = camera.rad_rotation.y - math.atan((@as(f32, @floatFromInt(n)) - @as(f32, @floatFromInt(self.width)) / 2.0) / camera.proj_dist);

            const result = physics.raycaster_raycast(camera.origin, angle, game_struct);

            const distance = result.?.distance;

            if (distance >= math.inf(f32)) continue;

            const cr: f32 = distance * math.cos(camera.rad_rotation.y - angle);
            const wall_height: u32 = @min(@as(u32, @intFromFloat(@max(1.0, camera.proj_dist / cr))), self.height);

            for (0..@as(usize, @intCast(wall_height))) |y| {
                const fade: u8 = @as(u8, @intFromFloat(math.clamp(distance * 50, 0, 255)));
                //const fade: u8 = 0;
                self.setPixel(n, @max(0, self.height / 2 - (@divTrunc(wall_height, 2)) + y), 255 - fade, 255 - fade, 255 - fade, 255);
            }
        }
    }

    pub fn clear(self: *Self) void {
        @memset(self.*.pixels, 0);
    }

    pub fn render(self: *Self) void {
        gl.bindTexture(self.texture, .@"2d");
        gl.texSubImage2D(
            .@"2d",
            0,
            0,
            0,
            self.width,
            self.height,
            .rgba,
            .unsigned_byte,
            self.pixels.ptr,
        );

        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(.{ .color = true, .stencil = false, .depth = false });

        gl.useProgram(self.shaderProgram);
        gl.bindVertexArray(self.VAO[0]);
        gl.drawElements(.triangles, 6, .unsigned_int, 0);

        self.window.swapBuffers();
    }

    pub fn update(self: *Self) void {
        processInput(self.window);
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

    fn processInput(window: glfw.Window) void {
        if (glfw.Window.getKey(window, glfw.Key.escape) == glfw.Action.press) {
            _ = glfw.Window.setShouldClose(window, true);
        }
    }
};
