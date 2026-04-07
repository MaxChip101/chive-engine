// const std = @import("std");
// const fs = std.fs;
// const heap = std.heap;

// const zlua = @import("zlua");
// const game = @import("game.zig");
// const gl = @import("zgl");
// const glfw = @import("glfw");

// fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
//     std.log.err("glfw: {}: {s}\n", .{ error_code, description });
// }

// pub fn main() !void {
//     glfw.setErrorCallback(errorCallback);
//     if (!glfw.init(.{})) {
//         std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
//         return error.GlfwInitFailed;
//     }
//     defer glfw.terminate();

//     // Create our window
//     const window = glfw.Window.create(640, 480, "Hello, zig-glfw!", null, null, .{}) orelse {
//         std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
//         return error.WindowCreationFailed;
//     };
//     defer window.destroy();

//     glfw.makeContextCurrent(window);

//     try gl.loadExtensions(.{}, glfw.getProcAddress);

//     gl.viewport(0, 0, 640, 480);

//     // Wait for the user to close the window.
//     while (!window.shouldClose()) {
//         gl.clearColor(0.1, 0.1, 0.1, 1.0);
//         gl.clear(gl.COLOR_BUFFER_BIT);
//         window.swapBuffers();

//         // Render your graphics here

//         glfw.pollEvents();
//     }

//     // var gpa = heap.GeneralPurposeAllocator(.{}){};
//     // const allocator = gpa.allocator();

//     // const screen_width = 800;
//     // const screen_height = 600;

//     // _ = screen_height;
//     // _ = screen_width;

//     // var game_struct: game.Game = try .init(allocator);

//     // const script_path = try game_struct.path_from_binaryZ("../test.lua");

//     // var lua = try zlua.Lua.init(allocator);
//     // defer lua.deinit();
//     // lua.openLibs();
//     // lua.doFile(script_path) catch |err| {
//     //     std.debug.print("{any}", .{err});
//     // };

//     // while (true) {}
// }

const std = @import("std");
const heap = std.heap;
const glfw = @import("glfw");
const gl = @import("zgl");

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

const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

// game is going to be a raycaster with pixel buffer

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (!glfw.init(.{})) {
        std.log.err("GLFW initialization failed", .{});
        return;
    }
    defer glfw.terminate();

    const window = glfw.Window.create(WindowSize.width, WindowSize.height, "mod game", null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 5,
    }) orelse {
        std.log.err("GLFW Window creation failed", .{});
        return;
    };
    defer window.destroy();

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
    defer gl.deleteShader(vertexShader);

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
    defer gl.deleteShader(fragmentShader);

    gl.shaderSource(fragmentShader, 1, &.{fragmentShaderSource});
    gl.compileShader(fragmentShader);

    gl.binding.getShaderiv(@intFromEnum(fragmentShader), gl.binding.COMPILE_STATUS, &success);

    if (success == 0) {
        infoLog = try gl.getShaderInfoLog(fragmentShader, allocator);
        std.log.err("{s}", .{infoLog});
    }

    const shaderProgram = gl.createProgram();
    std.debug.print("{any}", .{shaderProgram});
    defer gl.deleteProgram(shaderProgram);

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
    defer gl.deleteVertexArrays(&VAO);

    gl.genBuffers(&VBO);
    defer gl.deleteBuffers(&VBO);

    gl.genBuffers(&EBO);
    defer gl.deleteBuffers(&EBO);

    gl.bindVertexArray(VAO[0]);
    gl.bindBuffer(VBO[0], .array_buffer);

    gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

    gl.bindBuffer(EBO[0], .element_array_buffer);
    gl.bufferData(gl.BufferTarget.element_array_buffer, u32, &indices, gl.BufferUsage.static_draw);

    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 5 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(1, 2, gl.Type.float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    const pixels = try allocator.alloc(u8, WindowSize.width * WindowSize.height * 4);
    defer allocator.free(pixels);

    const texture = gl.Texture.gen();
    gl.bindTexture(texture, .@"2d");

    gl.textureImage2D(
        .@"2d",
        0,
        .rgba,
        WindowSize.width,
        WindowSize.height,
        .rgba,
        .unsigned_byte,
        pixels.ptr,
    );

    gl.texParameter(.@"2d", .min_filter, .nearest);
    gl.texParameter(.@"2d", .mag_filter, .nearest);

    while (!window.shouldClose()) {
        processInput(window);

        gl.bindTexture(texture, .@"2d");
        gl.texSubImage2D(
            .@"2d",
            0,
            0,
            0,
            WindowSize.width,
            WindowSize.height,
            .rgba,
            .unsigned_byte,
            pixels.ptr,
        );

        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(.{ .color = true, .stencil = false, .depth = false });

        gl.useProgram(shaderProgram);
        gl.bindVertexArray(VAO[0]);
        gl.drawElements(.triangles, 6, .unsigned_int, 0);

        window.swapBuffers();
        glfw.pollEvents();
    }
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
