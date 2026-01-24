local factory = require("level_graphics.factory")
local football = require("level_graphics.football")
local settings = require("settings")

local init = {}

local animation_map <total>: {Map: Graphics} = {
	football = football.new_graphics(),
	factory = factory.new_graphics()
}

function init.get_graphics(): Graphics
    return animation_map[settings.map]
end

function init.load_assets()
    for _, graphics in pairs(animation_map) do
        graphics:load_assets()
    end
end

return init
