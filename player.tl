require("const")
require("geometry")

global type Direction = enum
   "up"
   "down"
   "right"
   "left"
end

global record Player
	id: integer
   	position: Point
	direction: Direction
end

global function new_hit_box(new_position: Point): Rectangle
    return Rectangle.new(new_position.x, new_position.y, BLOCK_SIZE-1, BLOCK_SIZE-1)
end