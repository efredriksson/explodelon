-- Bouncing preview: no choreography yet. map_selection draws the static map
-- background on its own, so these empty hooks leave the screen as it is until
-- this is built out like football.tl / factory.tl.

local type MapPreview = require("map_preview.interfaces")

local record BouncingPreview is MapPreview
end

local bouncing = {}

function bouncing.new(): MapPreview
    local self: BouncingPreview = setmetatable({}, {__index = BouncingPreview})
    return self
end

function BouncingPreview:update(_: number)
end

function BouncingPreview:draw()
end

function BouncingPreview:leave()
end

return bouncing
