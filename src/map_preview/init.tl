local factory = require("map_preview.factory")
local settings = require("settings")

local type Map = settings.Map
local type MapPreview = require("map_preview.interfaces")

local map_preview = {}

function map_preview.for_map(map: Map): MapPreview
    if map == "factory" then
        return factory.new()
    end
    return nil
end

return map_preview
