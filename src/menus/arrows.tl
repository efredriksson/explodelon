-- The step arrows the picker screens flank their selection with.

local images = require("engine.images")
local screen = require("screen")

local left_image: Image
local right_image: Image
local left_shade_image: Image
local right_shade_image: Image

local ARROW_MARGIN = 6

local arrows = {}

function arrows.load_assets()
    right_image, left_image = images.new_mirrored_pair("assets/arrow_right.png")
    left_shade_image, right_shade_image = images.new_mirrored_pair(
        "assets/arrow_shade.png"
    )
end

function arrows.left(): Image
    return left_image
end

function arrows.right(): Image
    return right_image
end

function arrows.left_shade(): Image
    return left_shade_image
end

function arrows.right_shade(): Image
    return right_shade_image
end

function arrows.draw_shaded(area_top: number)
    local arrow_y = (screen.HEIGHT + area_top - left_image:getHeight()) / 2

    lutro.graphics.draw(left_shade_image, 0, 0)
    lutro.graphics.draw(left_image, ARROW_MARGIN, arrow_y)

    lutro.graphics.draw(
        right_shade_image, screen.WIDTH - right_shade_image:getWidth(), 0
    )
    local right_x = screen.WIDTH - ARROW_MARGIN - right_image:getWidth()
    lutro.graphics.draw(right_image, right_x, arrow_y)
end

return arrows
