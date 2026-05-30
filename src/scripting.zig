const std = @import("std");
const mem = std.mem;

const render = @import("render.zig");
const objects = @import("objects.zig");
const scenes = @import("scenes.zig");
const vectors = @import("vectors.zig");
const tools = @import("tools.zig");

const zlua = @import("zlua");

pub const ScriptManager = struct {
    allocator: mem.Allocator,

    scene_list: std.ArrayList(scenes.Scene),
    cameras: std.ArrayList(objects.Camera),

    const push_idx = -2;
    const stack_top_idx = -1;

    const chive_funcs = [_]zlua.FnReg{
        .{ .name = "InitChive", .func = zlua.wrap(initChive) },
        .{ .name = "CreateScene", .func = zlua.wrap(createScene) },
        .{ .name = "CreateSurface", .func = zlua.wrap(createSurface) },
        .{ .name = "CreateTexture", .func = zlua.wrap(createTexture) },
        .{ .name = "LoadTextureAtlas", .func = zlua.wrap(loadTextureAtlas) },
        .{ .name = "CreateCamera", .func = zlua.wrap(createCamera) },
    };

    // const ctools_funcs = [_]zlua.FnReg{
    //     .{.name = ""}
    // };

    const Self = @This();

    var lua: *zlua.Lua = undefined;
    var self_ptr: *Self = undefined;

    pub fn init(allocator: mem.Allocator) !Self {
        lua = try zlua.Lua.init(allocator);
        lua.openLibs();

        const main_script = try tools.path_from_binaryZ(allocator, "scripts/main.lua");
        defer allocator.free(main_script);

        lua.doFile(main_script) catch |err| {
            std.debug.print("{any}", .{err});
            return err;
        };

        const scene_list: std.ArrayList(scenes.Scene) = .init(allocator);
        const cameras: std.ArrayList(objects.Camera) = .init(allocator);
        const renderer: render.Renderer = .init(allocator: mem.Allocator, name: []const u8, width: u32, height: u32, display_method: DisplayMethod, resolution_width: u32, resolution_height: u32, texture_atlas_size: usize, texture_atlas_count: usize)


        return .{
            .allocator = allocator,
            .scene_list = scene_list,
            .cameras = cameras,
        };
    }

    pub fn deinit(self: Self) void {
        lua.deinit();
        self.scene_list.deinit();
        self.cameras.deinit();
    }

    fn createScene() i32 {
        const scene = scenes.Scene.init(self.allocator);
        const scene_id = self.scene_list.items.len;
        self.scene_list.append(scene) catch |err| {
            if (err == error.OutOfMemory) {
                std.log.debug("Out of Memory", .{});
                return;
            }
        };

        lua.pushInteger(scene_id);
        return 1;
    }

    fn createTexture() i32 {
        // texture

        const scene = scenes.Scene.init(self.allocator);
        const scene_id = self.scene_list.items.len;
        self.scene_list.append(scene) catch |err| {
            if (err == error.OutOfMemory) {
                std.log.debug("Out of Memory", .{});
                return 1;
            }
        };

        lua.pushInteger(scene_id);
        return 1;
    }

    fn loadTextureAtlas() i32 {
        // texture
        const scene = scenes.Scene.init(self.allocator);
        const scene_id = self.scene_list.items.len;
        self.scene_list.append(scene) catch |err| {
            if (err == error.OutOfMemory) {
                std.log.debug("Out of Memory", .{});
                return 1;
            }
        };

        lua.pushInteger(scene_id);
        return 1;
    }

    fn createSurface() i32 {
        const scene_id: u32 = pullInt(1);
        const position = pullVec3(2);
        const normal = pullVec3(3);
        const rotation = pullNumber(4);
        const size = pullVec2(5);
        const texture_id: u32 = pullInt(6);

        const surface: objects.Surface = .{
            .position = position,
            .normal = normal,
            .rotation = rotation,
            .size = size,
            .texture_id = texture_id,
        };

        const surface_id = self.scene_list.items[scene_id].addSurface(surface) catch |err| {
            if (err == error.OutOfMemory) {
                std.debug.print("Out of Memory", .{});
                return 1;
            }
        };

        lua.pushInteger(surface_id);
        return 1;
    }

    fn createCamera(self: Self) i32 {
        const position = pullVec3(1);
        const rotation = pullVec3(2);
        const fov = pullNumber(3);

        const camera = objects.Camera.init(position, rotation, fov);

        const camera_id = self.cameras.items.len;
        self.cameras.append(camera) catch {
            std.debug.print("Out of Memory", .{});
            return 1;
        };

        lua.pushInteger(camera_id);
        return 1;
    }

    pub fn start() !void {
        _ = lua.getGlobal("Start") catch unreachable;
        try lua.protectedCall(.{});
    }

    pub fn update(delta_time: f32) !void {
        _ = lua.getGlobal("Update") catch unreachable;
        lua.pushNumber(delta_time);
        try lua.protectedCall(.{ .args = 1 });
    }

    pub fn tick(delta_time: f32) !void {
        _ = lua.getGlobal("Tick") catch unreachable;
        lua.pushNumber(delta_time);
        try lua.protectedCall(.{ .args = 1 });
    }

    fn pushVec3(vector: vectors.Vec3) void {
        lua.createTable(0, 3);
        lua.pushNumber(vector.x);
        lua.setField(push_idx, "x");
        lua.pushNumber(vector.y);
        lua.setField(push_idx, "y");
        lua.pushNumber(vector.z);
        lua.setField(push_idx, "z");
    }

    fn pullVec3(idx: i32) vectors.Vec3 {
        lua.getField(idx, "x");
        const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
        lua.pop(1);
        lua.getField(idx, "y");
        const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
        lua.pop(1);
        lua.getField(idx, "z");
        const z: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
        lua.pop(1);
        return .{ .x = x, .y = y, .z = z };
    }

    fn pushVec2(vector: vectors.Vec2) void {
        lua.createTable(0, 2);
        lua.pushNumber(vector.x);
        lua.setField(push_idx, "x");
        lua.pushNumber(vector.y);
        lua.setField(push_idx, "y");
    }

    fn pullVec2(idx: i32) vectors.Vec2 {
        lua.getField(idx, "x");
        const x: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
        lua.pop(1);
        lua.getField(idx, "y");
        const y: f32 = @floatCast(lua.toNumber(stack_top_idx) catch 0);
        lua.pop(1);
        return .{ .x = x, .y = y };
    }

    fn pullNumber(idx: i32) f32 {
        return @floatCast(lua.toNumber(idx) catch 0.0);
    }

    fn pullInt(idx: i32) u32 {
        return @intCast(lua.toInteger(idx) catch 0);
    }

    fn pullString(idx: i32) [:0]const u8 {
        return lua.toString(idx) catch 0;
    }
};
