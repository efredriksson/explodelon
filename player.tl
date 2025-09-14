require("const")
require("geometry")

global record Player
	id: integer
   	position: Point
	asset_file: string
end

global function new_hit_box(new_position: Point): Rectangle
    return Rectangle.new(new_position.x, new_position.y, BLOCK_SIZE-1, BLOCK_SIZE-1)
end