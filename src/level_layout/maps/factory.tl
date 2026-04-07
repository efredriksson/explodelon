local vectors = require("engine.geometry.vectors")
local block_layouts = require("level_layout.block_layouts")
local grid = require("level_layout.grid")
local entities = require("level_layout.maps.entities")

local type MapLayout = entities.MapLayout
local type BlockType = entities.BlockType
local type Goal = entities.Goal
local type ConveyorBelt = entities.ConveyorBelt
local type Direction = vectors.Direction
local type Kinematic = require("kinematic")

local record FactoryLayout is MapLayout
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
end

function FactoryLayout.new(): FactoryLayout
    local self: FactoryLayout = setmetatable({}, {__index = FactoryLayout})
    return self
end

function FactoryLayout:get_goals(): {Goal}
    return {}
end

function FactoryLayout:get_conveyor_belts(): {ConveyorBelt}
    local function create_belt(i: integer, j: integer, dir: Direction): ConveyorBelt
        return ConveyorBelt.new(
            grid.get_tile_position(i, j), vectors.from_direction(dir)
        )
    end

    local dim = grid.dimensions()
    return {
        -- Outer ring
        create_belt(dim.x_min, dim.y_min, "down"),
        create_belt(dim.x_max, dim.y_max, "up"),
        create_belt(dim.x_max, dim.y_min, "left"),
        create_belt(dim.x_min, dim.y_max, "right"),
        -- Middle ring
        create_belt(dim.x_min + 4, dim.y_min + 2, "right"),
        create_belt(dim.x_max - 4, dim.y_max - 2, "left"),
        create_belt(dim.x_max - 4, dim.y_min + 2, "down"),
        create_belt(dim.x_min + 4, dim.y_max - 2, "up"),
        -- Inner ring
        create_belt(dim.x_min + 6, dim.y_min + 4, "down"),
        create_belt(dim.x_max - 6, dim.y_max - 4, "up"),
        create_belt(dim.x_max - 6, dim.y_min + 4, "left"),
        create_belt(dim.x_min + 6, dim.y_max - 4, "right"),
        -- Middle up/down
        create_belt(math.ceil(dim.x_max / 2), dim.y_min, "down"),
        create_belt(math.ceil(dim.x_max / 2), dim.y_max, "up"),
    }
end

function FactoryLayout:get_block_layout(
    occupies: {Kinematic}
): {integer: {integer: BlockType}}
    return block_layouts.grid(occupies)
end

function FactoryLayout:has_ice(): boolean
    return false
end

return FactoryLayout.new()
