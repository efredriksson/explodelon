require("const")
require("entity")
require("geometry")
require("itertools")

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

global function get_block_hitboxes(blocks: {ExplosionBlocking}): {Rectangle}
    local function hitbox_map_f(block: ExplosionBlocking): Rectangle
        return new_hitbox(block:get_position())
    end
    return map(blocks, hitbox_map_f)
end