local animations = require("engine.animations")
local init = require("level_graphics.maps.init")

local type Animation = animations.Animation

local BREAKING_FRAME_WIDTH = 24
local BREAKING_FRAME_TIME = 10 / 60

local soft_block_animations = {}

function soft_block_animations.get_rigid(): Animation
    return init.get_graphics():get_soft_block_rigid()
end

function soft_block_animations.get_revealed(): Animation
    return init.get_graphics():get_soft_block_revealed()
end

function soft_block_animations.get_exploding(): Animation
    return animations.new(
        init.get_graphics():get_soft_block_breaking_image(),
        BREAKING_FRAME_WIDTH,
        BREAKING_FRAME_TIME
    )
end

return soft_block_animations
