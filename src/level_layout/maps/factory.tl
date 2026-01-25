local entities = require("level_layout.maps.entities")
local grid = require("level_layout.grid")
local vectors = require("engine.geometry.vectors")

local type MapLayout = entities.MapLayout
local type Goal = entities.Goal
local type ConveyorBelt = entities.ConveyorBelt
local type Direction = vectors.Direction

local record FactoryLayout is MapLayout
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
end

function FactoryLayout.new(): FactoryLayout
    local self: FactoryLayout = setmetatable({}, { __index = FactoryLayout })
    return self
end

function FactoryLayout:get_goals(): {Goal}
	return {}
end

function FactoryLayout:get_conveyor_belts(): {ConveyorBelt}
	local function create_belt(i: integer, j: integer, dir: Direction): ConveyorBelt
		return ConveyorBelt.new(grid.get_tile_position(i, j), vectors.from_direction(dir))
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

return FactoryLayout.new()
