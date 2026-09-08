-- The step arrows the picker screens flank their selection with.

local images = require("engine.images")

local left_image: Image
local right_image: Image
local left_shade_image: Image
local right_shade_image: Image

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

return arrows
