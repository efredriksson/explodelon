require("level_graphics.interfaces")
local animations = require("animations")

local factory = {}

local background: Image
local soft_block_animation: Animation 
local soft_block_breaking_image: Image
local hard_block_animations: {boolean: Animation} = {}

local function load_image(rel_path: string): Image
    return lutro.graphics.newImage("assets/factory/" .. rel_path)
end

global record FactoryGraphics is Graphics
end

function FactoryGraphics:get_soft_block_exploding(): Animation
    return animations.new(soft_block_breaking_image, 24, 1 / 6)
end

function FactoryGraphics:get_soft_block_rigid(): Animation
    return soft_block_animation
end

function FactoryGraphics:get_hard_block(is_tall: boolean): Animation
    return hard_block_animations[is_tall]
end

function FactoryGraphics:draw_background()
    lutro.graphics.draw(background)
end

function FactoryGraphics:load_assets()
    background = load_image("background.png")
    soft_block_animation = animations.new(load_image("soft-block.png"), 16, 0.1)
    soft_block_breaking_image = load_image("soft-block-breaking.png")
    hard_block_animations[false] = animations.new(load_image("hard-block.png"), 16, 1)
    hard_block_animations[true] = animations.new(load_image("hard-block-tall.png"), 16, 1)
end

function factory.new_graphics(): FactoryGraphics
    local self: FactoryGraphics = setmetatable({}, { __index = FactoryGraphics })
    return self
end

return factory
