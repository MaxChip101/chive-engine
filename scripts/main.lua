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

local width = 800
local height = 600
local fps = 120
local title = "real"
local resolution_width = 480
local resolution_height = 460
local display_method = DisplayMethod.Windowed
local texture_atlas_size = 1024
local texture_atlas_count = 1

-- calls at start
function Start()
    -- setup must be called at the start
    chive.Setup(title, fps, width, height, display_method, resolution_width, resolution_height, texture_atlas_size, texture_atlas_count)
    local scene = chive.CreateScene()
    chive.SetScene(scene)
    local atlas = chive.LoadTextureAtlas("test.png")
    local texture = chive.CreateTexture(atlas, {x=0, y=0}, {x=1, y=1}, TextureType.Stretch, false, false, {r=1, g=1, b=1, a=1}, {x=1, y=1})
    local camera = chive.CreateCamera({ x=0, y=0, z=0 }, { x=0, y=0, z=0 }, 110)
    chive.SetCamera(camera)
    local surface = chive.CreateSurface(scene, {x=0, y=0, z=2}, {x=0, y=0, z=-1}, 0, {x=2, y=2}, texture)
end

-- calls every frame
function Update(delta)
    
end

-- calls when engine updates
function Tick(delta)
    
end
