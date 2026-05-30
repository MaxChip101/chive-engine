local chive = require("chive_enine_api")

local width = 800
local height = 600

-- calls at start before the engine initializes
function Start()
    local camera = chive.CreateCamera({ 0, 0, 0 }, { 0, 0, 0 }, 110, width);
    local surface
end

-- calls every frame
function Frame(deltaTime)

end

-- calls when engine updates
function Update(deltaTime)

end
