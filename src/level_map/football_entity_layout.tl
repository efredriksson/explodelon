
require("level_map.special_entity_layout")
local grid = require("level_map.grid")


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

return FootballLayout.new()
