require("entity")
require("geometry.points")
local const = require("const")
local itertools = require("itertools")
local rectangles = require("geometry.rectangles")
local settings = require("settings")


local hitboxes = {}

function hitboxes.new(position: Point): Rectangle
    return rectangles.new(position.x, position.y, const.BLOCK_SIZE, const.BLOCK_SIZE)
end

function hitboxes.draw(rectangle: Rectangle)
    if settings.draw_hitboxes then
        lutro.graphics.setColor(255, 255, 255)
        lutro.graphics.rectangle(
            "line", rectangle.x, rectangle.y, rectangle.width, rectangle.height
        )
    end
end

function hitboxes.get_for_blocks(blocks: {ExplosionBlocking}): {Rectangle}
    local function hitbox_map_f(block: ExplosionBlocking): Rectangle
        return hitboxes.new(block:get_position())
    end
    return itertools.map(blocks, hitbox_map_f)
end

return hitboxes
