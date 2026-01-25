local rectangles = require("engine.geometry.rectangles")
local points = require("engine.geometry.points")
local settings = require("engine.settings")

local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local hitboxes = {}

function hitboxes.new_block(position: Point): Rectangle
    return rectangles.new(position.x, position.y, settings.block_size, settings.block_size)
end

function hitboxes.draw(rectangle: Rectangle)
    if settings.draw_hitboxes then
        lutro.graphics.setColor(137, 242, 250)
        lutro.graphics.rectangle(
            "line", rectangle.x, rectangle.y, rectangle.width, rectangle.height
        )
    end
end

function hitboxes.draw_movement(rectangle: Rectangle)
    if settings.draw_hitboxes then
        lutro.graphics.setColor(247, 105, 250)
        lutro.graphics.rectangle(
            "line", rectangle.x, rectangle.y, rectangle.width, rectangle.height
        )
    end
end

return hitboxes
