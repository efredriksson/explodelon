require("level_graphics.maps.interfaces")
local animations = require("engine.animations")

local football = {}

local background: Image
local soft_block_animation: Animation 
local soft_block_breaking_image: Image
local hard_block_animation: {boolean: Animation} = {}

local function load_image(rel_path: string): Image
    return lutro.graphics.newImage("assets/football/" .. rel_path)
end

global record FootballGraphics is MapGraphics
end

function FootballGraphics:get_soft_block_exploding(): Animation
    return animations.new(soft_block_breaking_image, 24, 1 / 6)
end

function FootballGraphics:get_soft_block_rigid(): Animation
    return soft_block_animation
end

function FootballGraphics:get_hard_block(is_tall: boolean): Animation
    return hard_block_animation[is_tall]
end

function FootballGraphics:draw_background()
    lutro.graphics.draw(background)
end

function FootballGraphics:load_assets()
    background = load_image("background.png")
    soft_block_animation = animations.new(load_image("soft-block.png"), 16, 0.1)
    soft_block_breaking_image = load_image("soft-block-breaking.png")
    hard_block_animation[false] = animations.new(load_image("hard-block.png"), 16, 1)
    hard_block_animation[true] = animations.new(load_image("hard-block-tall.png"), 16, 1)
end

function football.new_graphics(): FootballGraphics
    local self: FootballGraphics = setmetatable({}, { __index = FootballGraphics })
    return self
end

return football