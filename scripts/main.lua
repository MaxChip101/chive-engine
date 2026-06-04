local size = { x = 800, y = 600 }
local fps = 165
local resolution = { x = 480, y = 360 }
local display_mode = DisplayMode.Windowed
local texture_atlas_size = 1024
local texture_atlas_count = 5

local walkspeed = 4
local sprint_speed = 6
local player_speed = 0

local ground_friction = 12
local air_friction = 0
local slide_friction = 1
local friction = ground_friction
local current_speed_in_dir = 0

local air_control = 0.2

local sensitivity = 600
local cam_pos = { x = 0, y = 0, z = 0 }
local cam_rot = { x = 0, y = 0, z = 0 }
local velocity = { x = 0, y = 0, z = 0 }

local gravity = 16
local ground_plane = -2

local normal_height = 1
local crouch_height = 0.15
local player_height = normal_height
local is_sliding = false
local is_crouching = false

local jump_force = 5
local y_velocity = 0
local acceleration = 0

local is_grounded = false

local sprinting = false
local sprint_fov = 120
local fov = 110

local title = "Demo"

chive.setup(title, size, display_mode, resolution, texture_atlas_size, texture_atlas_count)
chive.setFps(fps)
local scene_id = chive.createScene()
chive.setCurrentScene(scene_id)

local atlas_id = chive.loadTextureAtlas("test.png")
local quandale_atlas = chive.loadTextureAtlas("green.png")

local texture_id = chive.createTexture(
    atlas_id,
    { x = 0, y = 0 },
    { x = 1, y = 1 },
    TextureType.Stretch,
    false,
    false,
    { r = 1, g = 1, b = 1, a = 1 },
    { x = 1, y = 1 }
)

local quandale_texture = chive.createTexture(
    quandale_atlas,
    { x = 0, y = 0 },
    { x = 1, y = 1 },
    TextureType.Stretch,
    false,
    false,
    { r = 1, g = 1, b = 1, a = 1 },
    { x = 1, y = 1 }
)

local camera = chive.createCamera(cam_pos, cam_rot, fov)
chive.setCurrentCamera(camera)

local floor = chive.createSurface({ x = 0, y = -2, z = 0 }, { x = 0, y = 1, z = 0 }, 0, { x = 2, y = 2 }, texture_id)
local ceil = chive.createSurface({ x = 0, y = 2, z = 0 }, { x = 0, y = 1, z = 0 }, 0, { x = 2, y = 2 }, texture_id)
local wall_back = chive.createSurface(
    { x = 0, y = 0, z = 2 },
    { x = 0, y = 0, z = -1 },
    0,
    { x = 2, y = 2 },
    texture_id
)
local wall_front = chive.createSurface(
    { x = 0, y = 0, z = -2 },
    { x = 0, y = 0, z = -1 },
    0,
    { x = 2, y = 2 },
    texture_id
)
local wall_left = chive.createSurface(
    { x = -2, y = 0, z = 0 },
    { x = 1, y = 0, z = 0 },
    0,
    { x = 2, y = 2 },
    texture_id
)
local wall_right = chive.createSurface(
    { x = 2, y = 0, z = 0 },
    { x = 1, y = 0, z = 0 },
    0,
    { x = 2, y = 2 },
    texture_id
)

local billboard = chive.createSurface(
    { x = 0, y = 0, z = 0 },
    { x = 1, y = 0, z = 0 },
    0,
    { x = 0.5, y = 0.5 },
    quandale_texture
)

local locked = false
local escape_pressed = false
local last_mouse_pos = chive.getMousePos()

function Update(delta)
    size = chive.getWindowSize()
    local mouse_pos = chive.getMousePos()
    local mouse_diff = { x = mouse_pos.x, y = mouse_pos.y }
    vec2.subtract(mouse_diff, last_mouse_pos)
    if locked then
        vec3.add(cam_rot, {
            x = (sensitivity * delta * -mouse_diff.y) / size.y,
            y = (sensitivity * delta * mouse_diff.x) / size.x,
            z = 0,
        })
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

    sprinting = chive.getKeyDown(Key.left_control)
    if sprinting then
        player_speed = sprint_speed
        if active_camera ~= sprint_camera then
            active_camera = sprint_camera
            chive.setCameraFov(camera, sprint_fov)
        end
    else
        player_speed = walkspeed
        if active_camera ~= walk_camera then
            active_camera = walk_camera
            chive.setCameraFov(camera, fov)
        end
    end

    local input_dir = { x = 0, y = 0, z = 0 }
    if chive.getKeyDown(Key.w) then
        vec3.add(input_dir, { x = math.sin(cam_rot.y), y = 0, z = math.cos(cam_rot.y) })
    end
    if chive.getKeyDown(Key.a) then
        vec3.add(input_dir, { x = -math.cos(cam_rot.y), y = 0, z = math.sin(cam_rot.y) })
    end
    if chive.getKeyDown(Key.s) then
        vec3.subtract(input_dir, { x = math.sin(cam_rot.y), y = 0, z = math.cos(cam_rot.y) })
    end
    if chive.getKeyDown(Key.d) then
        vec3.add(input_dir, { x = math.cos(cam_rot.y), y = 0, z = -math.sin(cam_rot.y) })
    end

    -- Normalize input direction
    if vec3.length(input_dir) > 0 then
        input_dir = vec3.unit(input_dir)
    end

    is_crouching = chive.getKeyDown(Key.left_shift)
    if is_crouching then
        player_height = crouch_height
    else
        player_height = normal_height
    end

    local current_speed_sq = (velocity.x * velocity.x) + (velocity.z * velocity.z)
    if is_grounded and is_crouching and current_speed_sq > 5 then
        is_sliding = true
    else
        is_sliding = false
    end

    if is_sliding then
        friction = slide_friction
        acceleration = 0 -- You can't accelerate with WASD while sliding
    elseif is_grounded then
        friction = ground_friction
        acceleration = player_speed * ground_friction
    else
        friction = air_friction
        acceleration = player_speed * air_control
    end

    current_speed_in_dir = (velocity.x * input_dir.x) + (velocity.z * input_dir.z)

    -- Apply acceleration
    if is_grounded or current_speed_in_dir < player_speed then
        vec3.add(velocity, {
            x = input_dir.x * acceleration * delta,
            y = 0,
            z = input_dir.z * acceleration * delta,
        })
    end

    -- Apply friction
    velocity.x = velocity.x - (velocity.x * friction * delta)
    velocity.z = velocity.z - (velocity.z * friction * delta)

    if chive.getKeyDown(Key.space) then
        if is_grounded then
            is_grounded = false
            y_velocity = jump_force
            friction = air_friction
        end
    end

    if chive.getKeyPressed(Key.t) then
        print("t")
        chive.setDisplayMode(DisplayMode.Borderless)
    end
    if chive.getKeyPressed(Key.y) then
        print("y")
        chive.setDisplayMode(DisplayMode.Windowed)
    end

    y_velocity = y_velocity - (gravity * delta)

    cam_pos.y = cam_pos.y + (y_velocity * delta)

    if cam_pos.y <= ground_plane + player_height then
        is_grounded = true
        friction = ground_friction
        cam_pos.y = ground_plane + player_height
        y_velocity = 0
    else
        is_grounded = false
    end

    local billboard_pos = chive.getSurfacePosition(billboard)
    local look_dir = { x = cam_pos.x, y = cam_pos.y, z = cam_pos.z }
    vec3.subtract(look_dir, billboard_pos)

    local new_normal = vec3.unit(look_dir)
    chive.setSurfaceNormal(billboard, new_normal)

    vec3.add(cam_pos, {
        x = velocity.x * delta,
        y = 0,
        z = velocity.z * delta,
    })
    chive.setCameraPosition(camera, cam_pos)
    chive.setCameraRadRotation(camera, cam_rot)
end

function FixedUpdate(fixed_delta) end
