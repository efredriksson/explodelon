-- Ice rink preview: no choreography yet. map_selection draws the static map
-- background on its own, so these empty hooks leave the screen as it is until
-- this is built out like football.tl / factory.tl.

local type MapPreview = require("map_preview.interfaces")

local record IceRinkPreview is MapPreview
end

local ice_rink = {}

function ice_rink.new(): MapPreview
    local self: IceRinkPreview = setmetatable({}, {__index = IceRinkPreview})
    return self
end

function IceRinkPreview:update(_: number)
end

function IceRinkPreview:draw()
end

function IceRinkPreview:leave()
end

return ice_rink
