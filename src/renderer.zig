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

pub const DisplayMethod = enum {
    Windowed,
    FullScreen,
    Borderless,
};

pub const Texture = struct {
    uv_min: vectors.Vec2,
    uv_max: vectors.Vec2,
    tint: vectors.Color,
    altas_id: u32,
    flip_v: bool,
    flip_h: bool,
};

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
    VAO: gl.VertexArray,
    VBO: gl.Buffer,
    wallSSBO: gl.Buffer,
    textureSSBO: gl.Buffer,
    cameraSSBO: gl.Buffer,
    resultsSSBO: gl.Buffer,
    result_buffer: []physics.RayCastResult,
    max_walls: u32,
    render_scale: u32,

    texture_list: std.ArrayList(Texture),

    texture_atlas: gl.Texture,
    texture_atlas_size: usize,
    texture_atlas_count: usize,

    compute_width_loc: ?u32,
    compute_height_loc: ?u32,
    compute_wall_count_loc: ?u32,
    compute_max_walls_loc: ?u32,
    compute_render_scale_loc: ?u32,
    shader_width_loc: ?u32,
    shader_height_loc: ?u32,
    shader_max_walls_loc: ?u32,
    shader_render_scale_loc: ?u32,
    shader_texture_atlas_loc: ?u32,

    const Self = @This();

    const max_compute_x_groups = 64;

    const vertexShaderSource = @embedFile("shaders/vertex.glsl");
    const fragmentShaderSource = @embedFile("shaders/fragment.glsl");
    const computeShaderSource = @embedFile("shaders/compute.glsl");

    pub fn init(allocator: mem.Allocator, name: []const u8, width: u32, height: u32, display_method: DisplayMethod, max_walls: u32, render_scale: u32, texture_atlas_size: usize, texture_atlas_count: usize) !Self {
        var init_status = glfw.init(.{ .platform = .wayland });

        if (!init_status) {
            std.log.info("Failed to init Wayland, trying alternative", .{});
            init_status = glfw.init(.{});
        }

        if (!init_status) {
            return error.GLFWInitFailed;
        }

        const name_c = try allocator.dupeZ(u8, name);
        defer allocator.free(name_c);

        // fix the launch options
        // launch on the monitor that is focused
        // fix fullscreen and borderless for linux (may be fixed for windows or broken)

        var hints: glfw.Window.Hints = .{
            .opengl_profile = .opengl_core_profile,
            .context_version_major = 4,
            .context_version_minor = 5,
        };

        var monitor = if (display_method == .FullScreen or display_method == .Borderless)
            glfw.Monitor.getPrimary()
        else
            null;

        const video_mode = monitor.?.getVideoMode();

        if (display_method == .Borderless) {
            hints.decorated = false;
            hints.red_bits = @intCast(video_mode.?.getRedBits());
            hints.green_bits = @intCast(video_mode.?.getGreenBits());
            hints.blue_bits = @intCast(video_mode.?.getBlueBits());
            hints.refresh_rate = @intCast(video_mode.?.getRefreshRate());
        }

        const window_width = if (display_method == .Borderless) video_mode.?.getWidth() else width;
        const window_height = if (display_method == .Borderless) video_mode.?.getHeight() else height;

        const window = glfw.Window.create(window_width, window_height, name_c, null, null, hints) orelse {
            return error.GLFWWindowCreateFailed;
        };

        if (display_method == .FullScreen or display_method == .Borderless) {
            window.maximize();
        }

        if (display_method == .Borderless)
            window.setPos(.{ .x = 0, .y = 0 });

        glfw.makeContextCurrent(window);
        //glfw.swapInterval();
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

        const shader_width_loc = gl.getUniformLocation(shaderProgram, "screen_width");
        const shader_height_loc = gl.getUniformLocation(shaderProgram, "screen_height");
        const shader_max_walls_loc = gl.getUniformLocation(shaderProgram, "max_walls");
        const shader_render_scale_loc = gl.getUniformLocation(shaderProgram, "render_scale");
        const shader_texture_atlas_loc = gl.getUniformLocation(shaderProgram, "texture_atlas");

        const computeShader = gl.createShader(.compute);

        gl.shaderSource(computeShader, 1, &.{computeShaderSource});
        gl.compileShader(computeShader);

        status = gl.getShader(computeShader, .compile_status);
        if (status == 0) {
            const infoLog = try gl.getShaderInfoLog(computeShader, allocator);
            std.log.err("{s}", .{infoLog});
            defer allocator.free(infoLog);
            return error.FailedToMakeComputeShader;
        }

        const computeProgram = gl.createProgram();
        gl.attachShader(computeProgram, computeShader);
        gl.linkProgram(computeProgram);

        status = gl.getProgram(computeProgram, .link_status);
        if (status == 0) {
            const infoLog = try gl.getProgramInfoLog(computeProgram, allocator);
            std.log.err("{s}", .{infoLog});
            defer allocator.free(infoLog);
            return error.FailedToMakeComputeProgram;
        }

        gl.useProgram(computeProgram);

        const compute_width_loc = gl.getUniformLocation(computeProgram, "screen_width");
        const compute_height_loc = gl.getUniformLocation(computeProgram, "screen_height");
        const compute_wall_count_loc = gl.getUniformLocation(computeProgram, "wall_count");
        const compute_max_walls_loc = gl.getUniformLocation(computeProgram, "max_walls");
        const compute_render_scale_loc = gl.getUniformLocation(computeProgram, "render_scale");

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
        const textureSSBO = gl.genBuffer();
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

        const result_buffer = try allocator.alloc(physics.RayCastResult, (width * max_walls) / render_scale);
        errdefer allocator.free(result_buffer);

        gl.bindBuffer(resultsSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, physics.RayCastResult, result_buffer, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 2, resultsSSBO);

        gl.bindBuffer(textureSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, Texture, &[_]Texture{}, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 3, textureSSBO);

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

        const texture_list: std.ArrayList(Texture) = .init(allocator);

        // work on a system for loading and unloading texture atlases

        return .{
            .allocator = allocator,
            .width = window_width,
            .height = window_height,
            .window = window,
            .fragmentShader = fragmentShader,
            .vertexShader = vertexShader,
            .shaderProgram = shaderProgram,
            .computeShader = computeShader,
            .computeProgram = computeProgram,
            .texture_atlas = texture_atlas,
            .texture_atlas_size = texture_atlas_size,
            .texture_atlas_count = 0,
            .texture_list = texture_list,
            .VAO = VAO,
            .VBO = VBO,
            .wallSSBO = wallSSBO,
            .textureSSBO = textureSSBO,
            .cameraSSBO = cameraSSBO,
            .resultsSSBO = resultsSSBO,
            .result_buffer = result_buffer,
            .max_walls = max_walls,
            .render_scale = render_scale,
            .shader_width_loc = shader_width_loc,
            .shader_height_loc = shader_height_loc,
            .shader_max_walls_loc = shader_max_walls_loc,
            .shader_texture_atlas_loc = shader_texture_atlas_loc,
            .shader_render_scale_loc = shader_render_scale_loc,
            .compute_width_loc = compute_width_loc,
            .compute_height_loc = compute_height_loc,
            .compute_max_walls_loc = compute_max_walls_loc,
            .compute_render_scale_loc = compute_render_scale_loc,
            .compute_wall_count_loc = compute_wall_count_loc,
        };
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
        gl.deleteBuffer(self.textureSSBO);
        gl.deleteBuffer(self.cameraSSBO);
        gl.deleteBuffer(self.resultsSSBO);
        gl.deleteTexture(self.texture_atlas);
        self.texture_list.deinit();
        self.allocator.free(self.result_buffer);
        self.window.destroy();
        glfw.terminate();
    }

    pub fn load_texture_atlas(self: *Self, data: []const u8) !u32 {
        const data_c = try self.allocator.dupeZ(u8, data);
        defer self.allocator.free(data_c);
        gl.activeTexture(.texture_0);
        gl.bindTexture(self.texture_atlas, .@"2d_array");
        gl.texSubImage3D(
            .@"2d_array",
            0,
            0,
            0,
            self.texture_atlas_count,
            self.texture_atlas_size,
            self.texture_atlas_size,
            1,
            .rgba,
            .unsigned_byte,
            data_c.ptr,
        );
        const pos = self.texture_atlas_count;
        self.*.texture_atlas_count += 1;
        return @as(u32, @intCast(pos));
    }

    pub fn add_texture(self: *Self, texture: Texture) !u32 {
        const pos = self.texture_list.items.len;
        try self.texture_list.append(texture);
        return @as(u32, @intCast(pos));
    }

    pub fn render_update(self: *Self, camera: *objects.Camera) !void {
        const size = self.window.getFramebufferSize();
        if (self.width == size.width and self.height == size.height) return;
        self.*.width = size.width;
        self.*.height = size.height;
        camera.updateProjectionDistance(self.width);
        self.*.result_buffer = try self.allocator.realloc(self.*.result_buffer, (self.width * self.max_walls) / self.render_scale);
        @memset(self.*.result_buffer, .{
            .distance = math.inf(f32),
            .position = 0,
            .wall_id = 0,
            .corrected_distance = 0,
        });

        gl.bindBuffer(self.resultsSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, physics.RayCastResult, self.result_buffer, .dynamic_draw);
        gl.bindBufferBase(.shader_storage_buffer, 2, self.resultsSSBO);
        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);
    }

    pub fn render(self: *Self, camera: *objects.Camera, world_struct: world.World) !void {
        const walls = world_struct.walls.items;
        const textures = self.texture_list.items;

        try render_update(self, camera);

        gl.bindBuffer(self.wallSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Wall, walls, .dynamic_draw);

        gl.bindBuffer(self.cameraSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, objects.Camera, &[_]objects.Camera{camera.*}, .dynamic_draw);

        gl.bindBuffer(self.textureSSBO, .shader_storage_buffer);
        gl.bufferData(.shader_storage_buffer, Texture, textures, .dynamic_draw);

        gl.bindBuffer(gl.Buffer.invalid, .shader_storage_buffer);

        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(.{ .color = true, .stencil = false, .depth = false });

        gl.useProgram(self.computeProgram);

        gl.uniform1i(self.compute_width_loc, @intCast(self.width));
        gl.uniform1i(self.compute_height_loc, @intCast(self.height));
        gl.uniform1ui(self.compute_wall_count_loc, @intCast(walls.len));
        gl.uniform1ui(self.compute_max_walls_loc, self.max_walls);
        gl.uniform1ui(self.compute_render_scale_loc, self.render_scale);

        const groups_x = (self.width + (max_compute_x_groups - 1)) / max_compute_x_groups;
        gl.binding.dispatchCompute(groups_x, 1, 1);
        gl.binding.memoryBarrier(gl.binding.SHADER_STORAGE_BARRIER_BIT);

        gl.useProgram(self.shaderProgram);

        gl.uniform1i(self.shader_width_loc, @intCast(self.width));
        gl.uniform1i(self.shader_height_loc, @intCast(self.height));
        gl.uniform1ui(self.shader_max_walls_loc, self.max_walls);
        gl.uniform1ui(self.shader_render_scale_loc, self.render_scale);

        gl.activeTexture(.texture_0);
        gl.bindTexture(self.texture_atlas, .@"2d_array");
        gl.uniform1i(self.shader_texture_atlas_loc, 0);

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
