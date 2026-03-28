local block_layouts = require("level_layout.block_layouts")
local grid = require("level_layout.grid")
local entities = require("level_layout.maps.entities")

local type MapLayout = entities.MapLayout
local type BlockType = entities.BlockType
local type Goal = entities.Goal
local type ConveyorBelt = entities.ConveyorBelt
local type Kinematic = require("kinematic")

local record FootballLayout is MapLayout
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
end

function FootballLayout.new(): FootballLayout
    local self: FootballLayout = setmetatable({}, { __index = FootballLayout })
    return self
end

function FootballLayout:get_goals(): {Goal}
    return {
        Goal.new(grid.get_tile_position(-1, 4), grid.get_tile_position(-1, 6)),
        Goal.new(grid.get_tile_position(-1, 6), grid.get_tile_position(-1, 4)),
        Goal.new(grid.get_tile_position(17, 4), grid.get_tile_position(17, 6)),
        Goal.new(grid.get_tile_position(17, 6), grid.get_tile_position(17, 4)),
    }
end

function FootballLayout:get_conveyor_belts(): {ConveyorBelt}
    return {}
end

function FootballLayout:get_block_layout(occupies: {Kinematic}): {integer: {integer: BlockType}}
    return block_layouts.grid(occupies)
end

function FootballLayout:has_ice(): boolean
    return false
end

return FootballLayout.new()
