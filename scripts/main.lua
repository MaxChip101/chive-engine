local title = "real"
local size = { x = 800, y = 600 }
local fps = 120
local resolution = { x = 1080, y = 720 }
local display_mode = DisplayMode.Windowed
local texture_atlas_size = {x = 1024, y = 1024}
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
local atlas_id = chive.loadTextureAtlasPath("test.png")
local texture_id = chive.createTexture(atlas_id, { x = 0, y = 0 }, { x = 1, y = 1 }, TextureType.Stretch,
    { r = 1, g = 1, b = 1, a = 1 }, { x = 1, y = 1 })
local camera_id = chive.createCamera(cam_pos, cam_rot, 110)
chive.setCurrentCamera(camera_id)
local billboard_id = chive.createBillboard({ x = 0, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, 0, { x = 1, y = 1 }, texture_id)
local surface_id = chive.createSurface({ x = 0, y = 0, z = 2 }, { x = 0, y = 0, z = -1 }, 0, { x = 2, y = 2 }, true, texture_id)

local prefab_id = chive.createPrefab(surface_id, 1, billboard_id, 1)
local object_id = chive.createObject(scene_id, { x = 0, y = 0, z = 2 }, { x = 0, y = 0, z = 0 }, { x = 2, y = 1, z = 1 }, prefab_id)
local locked = false
local escape_pressed = false
local last_mouse_pos = chive.getMousePos()

local obj_rot = {x = 0, y = 0, z = 0}

function Update(delta)
    size = chive.getWindowSize()
    local mouse_pos = chive.getMousePos()
    local mouse_diff = { x = mouse_pos.x, y = mouse_pos.y }
    vec2.subtractAssign(mouse_diff, last_mouse_pos)
    if locked then
        vec3.addAssign(cam_rot,
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

    vec3.addAssign(obj_rot, {x = 0, y = 0, z = delta * 10})
    chive.setObjectRotation(object_id, scene_id, obj_rot);

    vec3.multiplyAssign(velocity, 0)
    if chive.getKeyDown(Key.w) then
        vec3.addAssign(velocity, { x = math.sin(cam_rot.y), y = 0, z = math.cos(cam_rot.y) })
    end
    if chive.getKeyDown(Key.a) then
        vec3.addAssign(velocity, { x = -math.cos(cam_rot.y), y = 0, z = math.sin(cam_rot.y) })
    end
    if chive.getKeyDown(Key.s) then
        vec3.subtractAssign(velocity, { x = math.sin(cam_rot.y), y = 0, z = math.cos(cam_rot.y) })
    end
    if chive.getKeyDown(Key.d) then
        vec3.addAssign(velocity, { x = math.cos(cam_rot.y), y = 0, z = -math.sin(cam_rot.y) })
    end
    if chive.getKeyDown(Key.space) then
        vec3.addAssign(velocity, { x = 0, y = 1, z = 0 })
    end
    if chive.getKeyDown(Key.left_shift) then
        vec3.subtractAssign(velocity, { x = 0, y = 1, z = 0 })
    end
    if chive.getKeyDown(Key.x) then
        vec3.addAssign(cam_rot, { x = 0, y = 0, z = 2 * delta })
    end
    if chive.getKeyDown(Key.z) then
        vec3.subtractAssign(cam_rot, { x = 0, y = 0, z = 2 * delta })
    end
    if chive.getKeyPressed(Key.t) then
        print("t")
        chive.setDisplayMode(DisplayMode.Borderless)
    end
    if chive.getKeyPressed(Key.y) then
        print("y")
        chive.setDisplayMode(DisplayMode.Windowed)
    end

    local unit = vec3.unit(velocity)
    vec3.multiplyAssign(unit, walkspeed * delta)
    vec3.addAssign(cam_pos, unit)
    chive.setCameraPosition(camera_id, cam_pos)
    chive.setCameraRadRotation(camera_id, cam_rot)
end

function FixedUpdate(fixed_delta)

end
