const std = @import("std");
const builtin = @import("builtin");
const heap = std.heap;
const mem = std.mem;
const math = std.math;
const glfw = @import("glfw");
const gl = @import("zgl");

const objects = @import("objects.zig");
const scene_manager = @import("scene_manager.zig");
const physics = @import("physics.zig");
const vectors = @import("vectors.zig");

pub const DisplayMode = enum(u32) {
    Windowed = 0,
    FullScreen = 1,
    Borderless = 2,
    BorderlessWindowed = 3,
};

pub const Renderer = struct {
    width: u32,
    height: u32,
    allocator: mem.Allocator,

    window: glfw.Window,

    fragmentShader: gl.Shader,
    vertexShader: gl.Shader,
    shaderProgram: gl.Program,
    VAO: gl.VertexArray,
    VBO: gl.Buffer,
    surfaceSSBO: gl.Buffer,
    textureSSBO: gl.Buffer,
    cameraSSBO: gl.Buffer,
    resolution_width: u32,
    resolution_height: u32,

    display_mode: DisplayMode,

    last_texture_id: u32,
    texture_objects: std.AutoArrayHashMap(u32, objects.Texture),

    texture_atlas: gl.Texture,
    texture_atlas_size: usize,
    texture_atlas_count: usize,
    texture_atlas_index: usize,

    width_loc: ?u32,
    height_loc: ?u32,
    surface_count_loc: ?u32,
    resolution_width_loc: ?u32,
    resolution_height_loc: ?u32,
    texture_atlas_loc: ?u32,

    const Self = @This();

    const max_compute_x_groups = 64;

    const vertexShaderSource = @embedFile("shaders/vertex.glsl");
    const fragmentShaderSource = @embedFile("shaders/fragment.glsl");

    pub fn init(allocator: mem.Allocator, title: [:0]const u8, width: u32, height: u32, display_mode: DisplayMode, resolution_width: u32, resolution_height: u32, texture_atlas_size: usize, texture_atlas_count: usize) !Self {
        const glfw_init = switch (builtin.os.tag) {
            .linux => glfw.init(.{ .platform = .wayland }),
            else => glfw.init(.{}),
        };

        if (!glfw_init) {
            return error.GLFWInitFailed;
        }

        var hints: glfw.Window.Hints = .{
            .opengl_profile = .opengl_core_profile,
            .context_version_major = 4,
            .context_version_minor = 5,
            .focus_on_show = true,
            .focused = true,
        };

        var window_width = width;
        var window_height = height;

        var monitor = glfw.Monitor.getPrimary();
        const video_mode = monitor.?.getVideoMode();

        hints.red_bits = @intCast(video_mode.?.getRedBits());
        hints.green_bits = @intCast(video_mode.?.getGreenBits());
        hints.blue_bits = @intCast(video_mode.?.getBlueBits());
        hints.refresh_rate = @intCast(video_mode.?.getRefreshRate());

        if (display_mode == .BorderlessWindowed or display_mode == .Windowed) {
            const screen_width: c_int = @intCast(video_mode.?.getWidth());
            const screen_height: c_int = @intCast(video_mode.?.getHeight());
            hints.position_x = @divTrunc(screen_width - @as(c_int, @intCast(window_width)), 2);
            hints.position_y = @divTrunc(screen_height - @as(c_int, @intCast(window_height)), 2);
        }
        if (display_mode == .Borderless or display_mode == .BorderlessWindowed) {
            hints.decorated = false;
        }
        if (display_mode == .Borderless or display_mode == .FullScreen) {
            window_width = video_mode.?.getWidth();
            window_height = video_mode.?.getHeight();
            hints.maximized = true;
        }
        if (display_mode == .FullScreen or display_mode == .BorderlessWindowed or display_mode == .Windowed) {
            monitor = null;
        }

        const window = glfw.Window.create(window_width, window_height, title, monitor, null, hints) orelse {
            return error.GLFWWindowCreateFailed;
        };

        // if (display_mode == .BorderlessWindowed) {
        //     window.setAttrib(.decorated, false);
        // }

        glfw.makeContextCurrent(window);
        //glfw.swapInterval(1);
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

        var status: c_int = gl.getShader(vertexShader, .compile_status);

        if (status == 0) {
            const infoLog = try gl.getShaderInfoLog(vertexShader, allocator);
            std.log.err("{s}", .{infoLog});
            defer allocator.free(infoLog);
            return error.FailedToMakeVertexShader;
        }

        const fragmentShader = gl.createShader(.fragment);

        gl.shaderSource(fragmentShader, 1, &.{fragmentShaderSource});
        gl.compileShader(fragmentShader);

        status = gl.getShader(fragmentShader, .compile_status);
        if (status == 0) {
            const infoLog = try gl.getShaderInfoLog(fragmentShader, allocator);
            std.log.err("{s}", .{infoLog});
            defer allocator.free(infoLog);
            return error.FailedToMakeFragmentShader;
        }

        const shaderProgram = gl.createProgram();

        gl.attachShader(shaderProgram, vertexShader);
        gl.attachShader(shaderProgram, fragmentShader);
        gl.linkProgram(shaderProgram);

        status = gl.getProgram(shaderProgram, .link_status);
        if (status == 0) {
            const infoLog = try gl.getProgramInfoLog(shaderProgram, allocator);
            std.log.err("{s}", .{infoLog});
            defer allocator.free(infoLog);
            return error.FailedToMakeShaderProgram;
        }
        gl.useProgram(shaderProgram);

        const width_loc = gl.getUniformLocation(shaderProgram, "screen_width");
        const height_loc = gl.getUniformLocation(shaderProgram, "screen_height");
        const surface_count_loc = gl.getUniformLocation(shaderProgram, "surface_count");
        const resolution_width_loc = gl.getUniformLocation(shaderProgram, "resolution_width");
        const resolution_height_loc = gl.getUniformLocation(shaderProgram, "resolution_height");
        const texture_atlas_loc = gl.getUniformLocation(shaderProgram, "texture_atlas");

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

        const surfaceSSBO = gl.genBuffer();
        const cameraSSBO = gl.genBuffer();
        const textureSSBO = gl.genBuffer();

        gl.bindBuffer(cameraSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Camera, &[_]objects.Camera{.{
            .position = .{ .x = 0, .y = 0, .z = 0 },
            .fov = 0,
            .rotation = .{ .x = 0, .y = 0, .z = 0 },
            .focal_length = 0,
        }}, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 0, cameraSSBO);

        gl.bindBuffer(textureSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Texture, &[_]objects.Texture{}, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 1, textureSSBO);

        gl.bindBuffer(surfaceSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Surface, &[_]objects.Surface{}, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 2, surfaceSSBO);

        gl.bindVertexArray(VAO);
        gl.bindBuffer(VBO, .array_buffer);

        gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

        gl.vertexAttribPointer(0, 2, gl.Type.float, false, 2 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);

        const texture_atlas = gl.genTexture();
        gl.bindTexture(texture_atlas, .@"2d_array");
        gl.textureImage3D(
            .@"2d_array",
            0,
            .rgba8,
            texture_atlas_size,
            texture_atlas_size,
            texture_atlas_count,
            .rgba,
            .unsigned_byte,
            null,
        );
        gl.generateMipmap(.@"2d_array");
        gl.texParameter(.@"2d_array", .min_filter, gl.TextureParameterType(.min_filter).nearest_mipmap_linear);
        gl.texParameter(.@"2d_array", .mag_filter, gl.TextureParameterType(.mag_filter).nearest);

        const texture_objects: std.AutoArrayHashMap(u32, objects.Texture) = .init(allocator);

        return .{
            .allocator = allocator,
            .width = window_width,
            .height = window_height,
            .window = window,
            .fragmentShader = fragmentShader,
            .vertexShader = vertexShader,
            .shaderProgram = shaderProgram,
            .display_mode = display_mode,
            .texture_atlas = texture_atlas,
            .texture_atlas_size = texture_atlas_size,
            .texture_atlas_count = texture_atlas_count,
            .texture_atlas_index = 0,
            .last_texture_id = 0,
            .texture_objects = texture_objects,
            .VAO = VAO,
            .VBO = VBO,
            .surfaceSSBO = surfaceSSBO,
            .textureSSBO = textureSSBO,
            .cameraSSBO = cameraSSBO,
            .resolution_width = resolution_width,
            .resolution_height = resolution_height,
            .width_loc = width_loc,
            .height_loc = height_loc,
            .surface_count_loc = surface_count_loc,
            .texture_atlas_loc = texture_atlas_loc,
            .resolution_width_loc = resolution_width_loc,
            .resolution_height_loc = resolution_height_loc,
        };
    }

    pub fn deinit(self: *Self) void {
        gl.deleteShader(self.vertexShader);
        gl.deleteShader(self.fragmentShader);
        gl.deleteProgram(self.shaderProgram);
        gl.deleteVertexArray(self.VAO);
        gl.deleteBuffer(self.VBO);
        gl.deleteBuffer(self.surfaceSSBO);
        gl.deleteBuffer(self.textureSSBO);
        gl.deleteBuffer(self.cameraSSBO);
        gl.deleteTexture(self.texture_atlas);
        self.texture_objects.deinit();
        self.window.destroy();
        glfw.terminate();
    }

    pub fn setDisplayMode(self: *Self, display_mode: DisplayMode) void {
        var window_width = self.width;
        var window_height = self.height;

        var monitor = glfw.Monitor.getPrimary();
        const video_mode = monitor.?.getVideoMode();
        if (display_mode == .FullScreen or display_mode == .Windowed) {
            self.window.setAttrib(.decorated, true);
        }
        if (display_mode == .BorderlessWindowed or display_mode == .Windowed) {
            self.window.restore();
            const screen_width: c_int = @intCast(video_mode.?.getWidth());
            const screen_height: c_int = @intCast(video_mode.?.getHeight());
            const x = @divTrunc(screen_width - @as(c_int, @intCast(window_width)), 2);
            const y = @divTrunc(screen_height - @as(c_int, @intCast(window_height)), 2);
            self.window.setPos(.{ .x = x, .y = y });
        }
        if (display_mode == .Borderless or display_mode == .BorderlessWindowed) {
            self.window.setAttrib(.decorated, false);
        }
        if (display_mode == .Borderless or display_mode == .FullScreen) {
            window_width = video_mode.?.getWidth();
            window_height = video_mode.?.getHeight();
            self.window.maximize();
        }
        if (display_mode == .FullScreen or display_mode == .BorderlessWindowed or display_mode == .Windowed) {
            monitor = null;
        }
        self.*.display_mode = display_mode;
    }

    pub fn setTitle(self: Self, title: [:0]const u8) void {
        self.window.setTitle(title);
    }

    pub fn setCursorPos(self: Self, pos: vectors.Vec2) void {
        self.window.setCursorPos(@floatCast(pos.x), @floatCast(pos.y));
    }

    pub fn setSize(self: Self, size: vectors.Vec2) void {
        self.window.setSize(.{ .width = @intFromFloat(size.x), .height = @intFromFloat(size.y) });
    }

    pub fn setResizable(self: Self, resizable: bool) void {
        self.window.setAttrib(.resizable, resizable);
    }

    // pub fn setIcon(self: Self) void {
    //     self.window.setIcon(allocator: mem.Allocator, images: ?[]const Image)
    // }

    pub fn loadTextureAtlas(self: *Self, data: []const u8) !u32 {
        if (self.texture_atlas_index >= self.texture_atlas_count) return error.OutOfTextureAtlasBuffers;
        //if (data.len != self.texture_atlas_size * self.texture_atlas_size) return error.IncorrectTextureAtlasSize; fix
        const data_c = try self.allocator.dupeZ(u8, data);
        defer self.allocator.free(data_c);
        gl.activeTexture(.texture_0);
        gl.bindTexture(self.texture_atlas, .@"2d_array");
        gl.texSubImage3D(
            .@"2d_array",
            0,
            0,
            0,
            self.texture_atlas_index,
            self.texture_atlas_size,
            self.texture_atlas_size,
            1,
            .rgba,
            .unsigned_byte,
            data_c.ptr,
        );
        const pos = self.texture_atlas_index;
        self.*.texture_atlas_index += 1;
        return @as(u32, @intCast(pos));
    }

    pub fn addTexture(self: *Self, texture: objects.Texture) !u32 {
        const id = self.last_texture_id;
        try self.texture_objects.put(id, texture);
        self.*.last_texture_id += 1;
        return id;
    }

    pub fn removeTexture(self: *Self, texture_id: u32) bool {
        return self.*.texture_objects.swapRemove(texture_id);
    }

    fn renderUpdate(self: *Self, camera: *objects.Camera) void {
        const size = self.window.getFramebufferSize();
        if ((self.width == size.width and self.height == size.height) and camera.focal_length != 0) return;
        self.*.width = size.width;
        self.*.height = size.height;
        camera.updateFocalLength(self.width);
    }

    pub fn renderScene(self: *Self, camera: *objects.Camera, scene: scene_manager.Scene) void {
        const surfaces = scene.surfaces.values();
        const surface_count = surfaces.len;
        const textures = self.texture_objects.values();

        self.renderUpdate(camera);

        gl.bindBuffer(self.surfaceSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Surface, surfaces, .dynamic_draw);

        gl.bindBuffer(self.cameraSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Camera, &[_]objects.Camera{camera.*}, .dynamic_draw);

        gl.bindBuffer(self.textureSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Texture, textures, .dynamic_draw);

        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);

        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(.{ .color = true, .stencil = false, .depth = false });

        gl.useProgram(self.shaderProgram);

        gl.uniform1i(self.width_loc, @intCast(self.width));
        gl.uniform1i(self.height_loc, @intCast(self.height));
        gl.uniform1ui(self.surface_count_loc, @intCast(surface_count));
        gl.uniform1ui(self.resolution_width_loc, self.resolution_width);
        gl.uniform1ui(self.resolution_height_loc, self.resolution_height);

        gl.activeTexture(.texture_0);
        gl.bindTexture(self.texture_atlas, .@"2d_array");
        gl.uniform1i(self.texture_atlas_loc, 0);
        gl.bindVertexArray(self.VAO);
        gl.drawArrays(.triangles, 0, 6);

        self.window.swapBuffers();
    }

    pub fn update(self: Self) void {
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
