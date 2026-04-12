local animations = require("engine.animations")

local type Animation = animations.Animation
local type MapGraphics = require("level_graphics.maps.interfaces")

local ice_rink = {}

local background: Image
local soft_block_animation: Animation
local soft_block_revealed_animation: Animation
local soft_block_breaking_image: Image
local hard_block_animation: {boolean: Animation} = {}

local function load_image(rel_path: string): Image
    return lutro.graphics.newImage("assets/ice_rink/" .. rel_path)
end

local record IceRinkGraphics is MapGraphics
end

function IceRinkGraphics:get_soft_block_exploding(): Animation
    return animations.new(soft_block_breaking_image, 24, 1 / 6)
end

function IceRinkGraphics:get_soft_block_rigid(): Animation
    return soft_block_animation
end

function IceRinkGraphics:get_soft_block_revealed(): Animation
    return soft_block_revealed_animation
end

function IceRinkGraphics:get_hard_block(is_tall: boolean): Animation
    return hard_block_animation[is_tall]
end

function IceRinkGraphics:draw_background()
    lutro.graphics.draw(background)
end

function IceRinkGraphics:load_assets()
    background = load_image("background.png")
    soft_block_animation = animations.new(load_image("soft-block.png"), 16, 0.1)
    soft_block_revealed_animation = animations.new(
        load_image("soft-block-revealed.png"), 16, 0.1
    )
    soft_block_breaking_image = load_image("soft-block-breaking.png")
    hard_block_animation[false] = animations.new(load_image("hard-block.png"), 16, 1)
    hard_block_animation[true] = animations.new(
        load_image("hard-block-tall.png"), 16, 1
    )
end

function ice_rink.new_graphics(): IceRinkGraphics
    local self: IceRinkGraphics = setmetatable({}, {__index = IceRinkGraphics})
    return self
end

return ice_rink
