local entities = require("level_layout.maps.entities")
local football = require("level_layout.maps.football")
local factory = require("level_layout.maps.factory")
local settings = require("settings")

local type Map = settings.Map
local type MapLayout = entities.MapLayout

local map_layouts <total>: {Map: MapLayout} = {
	football = football,
	factory = factory
}

local init = {}

function init.get_layout(): MapLayout
    return map_layouts[settings.map]
end

return init
