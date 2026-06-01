local DisplayMethod = {
    Windowed = 0,
    FullScreen = 1,
    Borderless = 2,
    BorderlessWindowed = 3
}

local TextureType = {
    Stretch = 0,
    Tile = 1,
}

local title = "real"
local width = 800
local height = 600
local fps = 120
local resolution_width = 480
local resolution_height = 460
local display_method = DisplayMethod.Windowed
local texture_atlas_size = 1024
local texture_atlas_count = 1

local pos_z = 0

local rot = 0

chive.Setup(title, fps, width, height, display_method, resolution_width, resolution_height, texture_atlas_size, texture_atlas_count)
local scene_id = chive.CreateScene()
chive.SetCurrentScene(scene_id)
local atlas_id = chive.LoadTextureAtlas("test.png")
local texture_id = chive.CreateTexture(atlas_id, {x=0, y=0}, {x=1, y=1}, TextureType.Stretch, false, false, {r=1, g=1, b=1, a=1}, {x=1, y=1})
local camera_id = chive.CreateCamera({ x=0, y=0, z=pos_z }, { x=0, y=0, z=0 }, 110)
chive.SetCurrentCamera(camera_id)
local surface_id = chive.CreateSurface({x=0, y=0, z=2}, {x=0, y=0, z=-1}, rot, {x=2, y=2}, texture_id)


function Update(delta)
    pos_z = pos_z - (0.1 * delta)
    rot = rot + (1 * delta)
    chive.SetCameraPosition(camera_id, { x=0, y=0, z=pos_z })
    chive.SetSurfaceRotation(surface_id, rot)
end

function Tick(delta)
    if chive.GetKeyDown(Key.e) then
        print("ok")
    end
end