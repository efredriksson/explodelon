local factory = require("level_graphics.maps.factory")
local football = require("level_graphics.maps.football")
local ice_rink = require("level_graphics.maps.ice_rink")
local settings = require("settings")

local type Map = settings.Map
local type MapGraphics = require("level_graphics.maps.interfaces")

local init = {}

local map_graphics <total>: {Map: MapGraphics} = {
	football = football.new_graphics(),
	factory = factory.new_graphics(),
	ice_rink = ice_rink.new_graphics(),
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
