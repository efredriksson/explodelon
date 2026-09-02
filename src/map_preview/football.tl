-- Football preview: no choreography yet. map_selection draws the static map
-- background on its own, so these empty hooks leave the screen as it is until
-- this is built out like factory.tl.

local type MapPreview = require("map_preview.interfaces")

local record FootballPreview is MapPreview
end

local football = {}

function football.new(): MapPreview
    local self: FootballPreview = setmetatable({}, {__index = FootballPreview})
    return self
end

function FootballPreview:update(_: number)
end

function FootballPreview:draw()
end

function FootballPreview:leave()
end

return football
