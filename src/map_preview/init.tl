local bouncing = require("map_preview.bouncing")
local factory = require("map_preview.factory")
local football = require("map_preview.football")
local ice_rink = require("map_preview.ice_rink")
local settings = require("settings")

local type Map = settings.Map
local type MapPreview = require("map_preview.interfaces")

local map_preview = {}

local builders <total>: {Map: function(): MapPreview} = {
    football = football.new,
    factory = factory.new,
    ice_rink = ice_rink.new,
    bouncing = bouncing.new,
}

function map_preview.for_map(map: Map): MapPreview
    return builders[map]()
end

return map_preview
