require("entity")
require("geometry.points")
local const = require("const")
local rectangles = require("geometry.rectangles")
local settings = require("settings")


local hitboxes = {}

function hitboxes.new_block(position: Point): Rectangle
    return rectangles.new(position.x, position.y, const.BLOCK_SIZE, const.BLOCK_SIZE)
end

function hitboxes.draw(rectangle: Rectangle)
    if settings.debug.draw_hitboxes then
        lutro.graphics.setColor(137, 242, 250)
        lutro.graphics.rectangle(
            "line", rectangle.x, rectangle.y, rectangle.width, rectangle.height
        )
    end
end

function hitboxes.draw_movement(rectangle: Rectangle)
    if settings.debug.draw_hitboxes then
        lutro.graphics.setColor(247, 105, 250)
        lutro.graphics.rectangle(
            "line", rectangle.x, rectangle.y, rectangle.width, rectangle.height
        )
    end
end

return hitboxes
