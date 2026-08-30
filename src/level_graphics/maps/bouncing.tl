local animations = require("engine.animations")

local type Animation = animations.Animation
local type MapGraphics = require("level_graphics.maps.interfaces")

local bouncing = {}

local background: Image
local soft_block_animation: Animation
local soft_block_revealed_animation: Animation
local soft_block_breaking_image: Image
local hard_block_animations: {boolean: Animation} = {}

local function load_image(rel_path: string): Image
    return lutro.graphics.newImage("assets/bouncing/" .. rel_path)
end

local record BouncingGraphics is MapGraphics
end

function BouncingGraphics:get_soft_block_exploding(): Animation
    return animations.new(soft_block_breaking_image, 24, 1 / 6)
end

function BouncingGraphics:get_soft_block_rigid(): Animation
    return soft_block_animation
end

function BouncingGraphics:get_soft_block_revealed(): Animation
    return soft_block_revealed_animation
end

function BouncingGraphics:get_hard_block(is_tall: boolean): Animation
    return hard_block_animations[is_tall]
end

function BouncingGraphics:draw_background()
    lutro.graphics.draw(background)
end

function BouncingGraphics:load_assets()
    background = load_image("background.png")
    soft_block_animation = animations.new(load_image("soft-block.png"), 16, 0.1)
    soft_block_revealed_animation = animations.new(
        load_image("soft-block-revealed.png"), 16, 0.1
    )
    soft_block_breaking_image = load_image("soft-block-breaking.png")
    hard_block_animations[false] = animations.new(load_image("hard-block.png"), 16, 1)
    hard_block_animations[true] = animations.new(
        load_image("hard-block-tall.png"), 16, 1
    )
end

function bouncing.new_graphics(): BouncingGraphics
    local self: BouncingGraphics = setmetatable({}, {__index = BouncingGraphics})
    return self
end

return bouncing
