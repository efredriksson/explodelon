local grid = require("level_layout.grid")

local type Kinematic = require("kinematic")

--- Tiles a walking player cannot step into: blocks, bombs and everything
-- outside the play area.
local record ClosedTiles
    closed: {integer: {integer: boolean}}
end

local closed_tiles = {ClosedTiles = ClosedTiles}

function closed_tiles.new(...: {any: Kinematic}): ClosedTiles
    local self: ClosedTiles = setmetatable({}, {__index = ClosedTiles})
    self.closed = {}
    for _, obstacles in ipairs({...}) do
        for _, obstacle in pairs(obstacles) do
            local i, j = grid.tile_indices(obstacle:get_position())
            self.closed[i] = self.closed[i] or {}
            self.closed[i][j] = true
        end
    end
    return self
end

function ClosedTiles:is_open(i: integer, j: integer): boolean
    local dimensions = grid.dimensions()
    local inside = i >= dimensions.x_min
        and i <= dimensions.x_max
        and j >= dimensions.y_min
        and j <= dimensions.y_max
    return inside and not (self.closed[i] and self.closed[i][j])
end

return closed_tiles
