--local chive = require("chive_enine_api") -- just for the lsp

local width = 800
local height = 600

print("ok")

-- calls at start before the engine initializes
function Start()
    --local camera = chive.CreateCamera({ 0, 0, 0 }, { 0, 0, 0 }, 110, width)
    --local surface = chive.CreateSurface({0,0, 2}, {0, 0, -1}, 0, {2, 2}, 0)
    print("start")
end

-- calls every frame
function Update(deltaTime)
    print("update")
end

-- calls when engine updates
function Tick(deltaTime)
    print("tick")
end
