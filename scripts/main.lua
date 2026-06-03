local title = "real"
local size = { x = 800, y = 600 }
local fps = 120
local resolution = { x = 480, y = 360 }
local display_mode = DisplayMode.Windowed
local texture_atlas_size = 1024
local texture_atlas_count = 1

local walkspeed = 3
local sensitivity = 600
local cam_pos = { x = 0, y = 0, z = 0 }
local cam_rot = { x = 0, y = 0, z = 0 }
local velocity = { x = 0, y = 0, z = 0 }

chive.setup(title, size, display_mode, resolution, texture_atlas_size, texture_atlas_count)
chive.setFps(fps)
local scene_id = chive.createScene()
chive.setCurrentScene(scene_id)
local atlas_id = chive.loadTextureAtlas("test.png")
local texture_id = chive.createTexture(atlas_id, { x = 0, y = 0 }, { x = 1, y = 1 }, TextureType.Stretch, false,
    false,
    { r = 1, g = 1, b = 1, a = 1 }, { x = 1, y = 1 })
local camera_id = chive.createCamera(cam_pos, cam_rot, 110)
chive.setCurrentCamera(camera_id)
local surface_id = chive.createSurface({ x = 0, y = 0, z = 2 }, { x = 0, y = 0, z = -1 }, 0, { x = 2, y = 2 },
    texture_id)
local locked = false
local escape_pressed = false
local last_mouse_pos = chive.getMousePos()

function Update(delta)
    size = chive.getWindowSize()
    local mouse_pos = chive.getMousePos()
    local mouse_diff = { x = mouse_pos.x, y = mouse_pos.y }
    vec2.subtract(mouse_diff, last_mouse_pos)
    if locked then
        vec3.add(cam_rot,
            { x = (sensitivity * delta * -mouse_diff.y) / size.y, y = (sensitivity * delta * mouse_diff.x) / size.x, z = 0 })
    end
    local escape_down = chive.getKeyDown(Key.escape)
    if escape_down and not escape_pressed then
        locked = not locked
        if locked then
            chive.setMouseState(MouseState.disabled)
        else
            chive.setMouseState(MouseState.normal)
        end
    end
    escape_pressed = escape_down

    last_mouse_pos = mouse_pos

    vec3.multiply(velocity, 0)
    if chive.getKeyDown(Key.w) then
        vec3.add(velocity, { x = math.sin(cam_rot.y), y = 0, z = math.cos(cam_rot.y) })
    end
    if chive.getKeyDown(Key.a) then
        vec3.add(velocity, { x = -math.cos(cam_rot.y), y = 0, z = math.sin(cam_rot.y) })
    end
    if chive.getKeyDown(Key.s) then
        vec3.subtract(velocity, { x = math.sin(cam_rot.y), y = 0, z = math.cos(cam_rot.y) })
    end
    if chive.getKeyDown(Key.d) then
        vec3.add(velocity, { x = math.cos(cam_rot.y), y = 0, z = -math.sin(cam_rot.y) })
    end
    if chive.getKeyDown(Key.space) then
        vec3.add(velocity, { x = 0, y = 1, z = 0 })
    end
    if chive.getKeyDown(Key.left_shift) then
        vec3.subtract(velocity, { x = 0, y = 1, z = 0 })
    end

    local unit = vec3.unit(velocity)
    vec3.multiply(unit, walkspeed * delta)
    vec3.add(cam_pos, unit)
    chive.setCameraPosition(camera_id, cam_pos)
    chive.setCameraRadRotation(camera_id, cam_rot)
end

function FixedUpdate(fixed_delta)

end
