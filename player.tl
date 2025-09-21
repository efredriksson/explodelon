require("const")
require("geometry")
require("animation")
require("entity")

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
	idle: boolean
	score: integer
	speed: integer
end

function Player.new(id: integer, position: Point): Player
	local self: Player = setmetatable({}, { __index = Player })
	self.id = id
	self.position = position
	self.direction = "down"
	self.idle = true
	self.score = 0
	self.speed = PLAYER_SPEED
	return self
end

global function new_hit_box(new_position: Point): Rectangle
    return Rectangle.new(new_position.x, new_position.y, BLOCK_SIZE-1, BLOCK_SIZE-1)
end

global record PlayerAnimation is Entity
	position: Point
	animation: Animation
end

function PlayerAnimation.new(animation: Animation, position: Point): PlayerAnimation
	local self: PlayerAnimation = setmetatable({}, { __index = PlayerAnimation })
	self.animation = animation
	self.position = position
	return self
end

local function convert_pos_for_character_draw(animation: Animation, pos: Point): Point
	local h = animation.image:getHeight()
	-- x: -1 and y: +1 is because of the sprite, look over when doing animations
	return Point.new(pos.x - 1, pos.y - h + BLOCK_SIZE + 1)
end

function PlayerAnimation:draw()
	local draw_pos = convert_pos_for_character_draw(self.animation, self.position)
	self.animation:draw(draw_pos.x, draw_pos.y)
end
