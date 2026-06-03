-- Auto Generated

---@class TextureType
---@field Stretch 0
---@field Tile 1

---@type TextureType
TextureType = TextureType

---@class DisplayMode
---@field Windowed 0
---@field FullScreen 1
---@field Borderless 2
---@field BorderlessWindowed 3

---@type DisplayMode
DisplayMode = DisplayMode

---@class Key
---@field unknown -1
---@field space 32
---@field apostrophe 39
---@field comma 44
---@field minus 45
---@field period 46
---@field slash 47
---@field zero 48
---@field one 49
---@field two 50
---@field three 51
---@field four 52
---@field five 53
---@field six 54
---@field seven 55
---@field eight 56
---@field nine 57
---@field semicolon 59
---@field equal 61
---@field a 65
---@field b 66
---@field c 67
---@field d 68
---@field e 69
---@field f 70
---@field g 71
---@field h 72
---@field i 73
---@field j 74
---@field k 75
---@field l 76
---@field m 77
---@field n 78
---@field o 79
---@field p 80
---@field q 81
---@field r 82
---@field s 83
---@field t 84
---@field u 85
---@field v 86
---@field w 87
---@field x 88
---@field y 89
---@field z 90
---@field left_bracket 91
---@field backslash 92
---@field right_bracket 93
---@field grave_accent 96
---@field world_1 161
---@field world_2 162
---@field escape 256
---@field enter 257
---@field tab 258
---@field backspace 259
---@field insert 260
---@field delete 261
---@field right 262
---@field left 263
---@field down 264
---@field up 265
---@field page_up 266
---@field page_down 267
---@field home 268
---@field end 269
---@field caps_lock 280
---@field scroll_lock 281
---@field num_lock 282
---@field print_screen 283
---@field pause 284
---@field F1 290
---@field F2 291
---@field F3 292
---@field F4 293
---@field F5 294
---@field F6 295
---@field F7 296
---@field F8 297
---@field F9 298
---@field F10 299
---@field F11 300
---@field F12 301
---@field F13 302
---@field F14 303
---@field F15 304
---@field F16 305
---@field F17 306
---@field F18 307
---@field F19 308
---@field F20 309
---@field F21 310
---@field F22 311
---@field F23 312
---@field F24 313
---@field F25 314
---@field kp_0 320
---@field kp_1 321
---@field kp_2 322
---@field kp_3 323
---@field kp_4 324
---@field kp_5 325
---@field kp_6 326
---@field kp_7 327
---@field kp_8 328
---@field kp_9 329
---@field kp_decimal 330
---@field kp_divide 331
---@field kp_multiply 332
---@field kp_subtract 333
---@field kp_add 334
---@field kp_enter 335
---@field kp_equal 336
---@field left_shift 340
---@field left_control 341
---@field left_alt 342
---@field left_super 343
---@field right_shift 344
---@field right_control 345
---@field right_alt 346
---@field right_super 347
---@field menu 348

---@type Key
Key = Key

---@class MouseState
---@field normal 212993
---@field hidden 212994
---@field disabled 212995
---@field captured 212996

---@type MouseState
MouseState = MouseState

---@class Vec2
---@field x number
---@field y number

---@type Vec2
Vec2 = Vec2

---@class Vec3
---@field x number
---@field y number
---@field z number

---@type Vec3
Vec3 = Vec3

---@class Color
---@field r number
---@field g number
---@field b number
---@field a number

---@type Color
Color = Color

---@class color
---@field zero Color
---@field black Color
---@field white Color

---@type color
color = color

---@class vec2
---@field zero Vec2
---@field one Vec2
---@field right Vec2
---@field up Vec2
---@field length Vec2
---@field length_squared Vec2
---@field multiply Vec2
---@field divide Vec2
---@field add Vec2
---@field subtract Vec2
---@field dot Vec2
---@field cross Vec2
---@field unit Vec2
---@field add fun(a: Vec2, b: Vec2))
---@field subtract fun(a: Vec2, b: Vec2)
---@field multiply fun(a: Vec2, scalar: number)
---@field divide fun(a: Vec2, scalar: number)
---@field length fun(a: Vec2): number
---@field lengthSquared fun(a: Vec2): number
---@field dot fun(a: Vec2, b: Vec2): number
---@field cross fun(a: Vec2, b: Vec2): number
---@field unit fun(a: Vec2): Vec2

---@type vec2
vec2 = vec2

---@class vec3
---@field zero Vec3
---@field one Vec3
---@field up Vec3
---@field right Vec3
---@field forward Vec3
---@field length Vec3
---@field length_squared Vec3
---@field multiply Vec3
---@field divide Vec3
---@field add Vec3
---@field subtract Vec3
---@field dot Vec3
---@field cross Vec3
---@field unit Vec3
---@field add fun(a: Vec3, b: Vec3)
---@field subtract fun(a: Vec3, b: Vec3)
---@field multiply fun(a: Vec3, scalar: number)
---@field divide fun(a: Vec3, scalar: number)
---@field length fun(a: Vec3): number
---@field lengthSquared fun(a: Vec3): number
---@field dot fun(a: Vec3, b: Vec3): number
---@field cross fun(a: Vec3, b: Vec3): Vec3
---@field unit fun(a: Vec3): Vec3

---@type vec3
vec3 = vec3

---@class chive
---@field setup fun(title: string, size: Vec2, display_mode: integer, resolution: Vec2, texture_atlas_size: integer, texture_atlas_count: integer)
---@field setTitle fun(title: string)
---@field setWindowSize fun(size: Vec2)
---@field setMousePos fun(pos: Vec2)
---@field setFps fun(fps: integer)
---@field getWindowSize fun(): Vec2
---@field createScene fun(): integer
---@field deleteScene fun(scene_id: integer): boolean
---@field setCurrentScene fun(scene_id: integer)
---@field createTexture fun(atlas_id: integer, uv_min: Vec2, uv_max: Vec2, texture_type: integer, flip_u: boolean, flip_v: boolean, tint: Color, size: Vec2): integer
---@field setTextureUVMin fun(texture_id: integer, uv_min: Vec2)
---@field setTextureUVMax fun(texture_id: integer, uv_max: Vec2)
---@field setTextureSize fun(texture_id: integer, size: Vec2)
---@field setTextureTint fun(texture_id: integer, tint: Color)
---@field setTextureUFlip fun(texture_id: integer, flip_u: boolean)
---@field setTextureVFlip fun(texture_id: integer, flip_v: boolean)
---@field setTextureAtlasID fun(texture_id: integer, atlas_id: integer)
---@field removeTexture fun(texture_id: integer): boolean
---@field loadTextureAtlas fun(atlas_path: string): integer
---@field createSurface fun(position: Vec3, normal: Vec3, rotation: number, size: Vec2, texture_id: integer): integer
---@field setSurfacePosition fun(surface_id: integer, position: Vec3)
---@field setSurfaceNormal fun(surface_id: integer, normal: Vec3)
---@field setSurfaceRotation fun(surface_id: integer, rotation: number)
---@field setSurfaceSize fun(surface_id: integer, size: Vec2)
---@field setSurfaceTextureID fun(surface_id: integer, texture_id: integer)
---@field removeSurface fun(surface_id: integer): boolean
---@field createCamera fun(position: Vec3, rotation: Vec3, fov: number): integer
---@field setCameraPosition fun(camera_id: integer, position: Vec3)
---@field setCameraRotation fun(camera_id: integer, rotation: Vec3)
---@field setCameraRadRotation fun(camera_id: integer, rad_rotation: Vec3)
---@field setCameraFov fun(camera_id: integer, fov: number)
---@field deletetCamera fun(camera_id: integer): boolean
---@field setCurrentCamera fun(camera_id: integer)
---@field getKeyDown fun(key: integer): boolean
---@field getKeyUp fun(key: integer): boolean
---@field getKeyRepeat fun(key: integer): boolean
---@field setMouseState fun(mouse_state: integer)
---@field getMousePos fun(): Vec2

---@type chive
chive = chive

---@param fixed_delta number
function FixedUpdate(fixed_delta) end

---@param delta number
function Update(delta) end
