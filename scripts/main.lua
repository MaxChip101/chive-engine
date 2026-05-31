---@class Vec2
---@field x number
---@field y number

---@class Vec3
---@field x number
---@field y number
---@field z number

---@class Color
---@field r number
---@field g number
---@field b number
---@field a number

---@class DisplayMethodEnum
---@field Windowed 0
---@field FullScreen 1
---@field Borderless 2
---@field BorderlessWindowed 3

---@class TextureTypeEnum
---@field Stretch 0
---@field Tile 1

---@class chive
---@field Setup fun(title: string, fps: integer, width: integer, height: integer, display_method: integer, resolution_width: integer, resolution_height: integer, texture_atlas_size: integer, texture_atlas_count: integer)
---@field CreateScene fun(): integer
---@field SetScene fun(scene_id: integer)
---@field LoadTextureAtlas fun(filename: string): integer
---@field CreateTexture fun(atlas_id: integer, uv_min: Vec2, uv_max: Vec2, texture_type: integer, flip_u: boolean, flip_v: boolean, tint: Color, size: Vec2): integer
---@field CreateCamera fun(position: Vec3, rotation: Vec3, fov: number): integer
---@field SetCamera fun(camera_id: integer)
---@field CreateSurface fun(scene_id: integer, position: Vec3, normal: Vec3, rotation: number, size: Vec2, texture_id: integer): integer

---@type chive
chive = chive

---@type DisplayMethodEnum
local DisplayMethod = {
    Windowed = 0,
    FullScreen = 1,
    Borderless = 2,
    BorderlessWindowed = 3
}

---@type TextureTypeEnum
local TextureType = {
    Stretch = 0,
    Tile = 1,
}

local width = 800
local height = 600
local fps = 120
local title = "real"
local resolution_width = 480
local resolution_height = 460
local display_method = DisplayMethod.Windowed
local texture_atlas_size = 1024
local texture_atlas_count = 1

--- Called once at startup. Must call chive.Setup first.
function Start()
    chive.Setup(title, fps, width, height, display_method, resolution_width, resolution_height, texture_atlas_size, texture_atlas_count)
    local scene = chive.CreateScene()
    chive.SetScene(scene)
    local atlas = chive.LoadTextureAtlas("test.png")
    local texture = chive.CreateTexture(atlas, {x=0, y=0}, {x=1, y=1}, TextureType.Stretch, false, false, {r=1, g=1, b=1, a=1}, {x=1, y=1})
    local camera = chive.CreateCamera({ x=0, y=0, z=0 }, { x=0, y=0, z=0 }, 110)
    chive.SetCamera(camera)
    local surface = chive.CreateSurface(scene, {x=0, y=0, z=2}, {x=0, y=0, z=-1}, 0, {x=2, y=2}, texture)
end

--- Called every frame.
---@param delta number milliseconds since last frame
function Update(delta)
    
end

--- Called every engine tick.
---@param delta number milliseconds since last frame
function Tick(delta)
    
end
