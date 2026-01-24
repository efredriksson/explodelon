local factory = require("level_graphics.maps.factory")
local football = require("level_graphics.maps.football")
local settings = require("settings")

local init = {}

local map_graphics <total>: {Map: MapGraphics} = {
	football = football.new_graphics(),
	factory = factory.new_graphics()
}

function init.get_graphics(): MapGraphics
    return map_graphics[settings.map]
end

function init.load_assets()
    for _, graphics in pairs(map_graphics) do
        graphics:load_assets()
    end
end

return init
