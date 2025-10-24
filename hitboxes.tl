require("const")
require("geometry")

local DRAW_HITBOXES = false

global function new_hitbox(new_position: Point): Rectangle
    return Rectangle.new(new_position.x, new_position.y, BLOCK_SIZE, BLOCK_SIZE)
end

global function draw_hitbox(rectangle: Rectangle)
    if DRAW_HITBOXES then
        lutro.graphics.setColor(255, 255, 255)
        lutro.graphics.rectangle(
            "line", rectangle.x, rectangle.y, rectangle.width, rectangle.height
        )
    end
end
