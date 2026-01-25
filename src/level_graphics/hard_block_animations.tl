local animations = require("engine.animations")
local init = require("level_graphics.maps.init") 

local type Animation = animations.Animation

local hard_block_animations = {}

function hard_block_animations.get(is_tall: boolean): Animation
	return init.get_graphics():get_hard_block(is_tall)
end

return hard_block_animations
