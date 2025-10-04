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

global type Action = enum
   "walk"
   "jump"
   "idle"
end

global type PlayerState = enum
	"foot"
	"mounted"
end

global record Player
	id: integer
   	position: Point
	direction: Direction
	action: Action
	state: PlayerState
	score: integer
	speed: integer
	bombs: integer
	fire: integer
	has_kick: boolean
	is_alive: boolean
end

function Player.new(id: integer, position: Point): Player
	local self: Player = setmetatable({}, { __index = Player })
	self.id = id
	self.position = position
	self.direction = "down"
	self.action = "idle"
	self.state = "foot"
	self.score = 0
	self.speed = PLAYER_SPEED
	self.bombs = 1
	self.fire = 2
	self.has_kick = false
	self.is_alive = true
	return self
end

function Player:won_game()
	self.score = self.score + 1
end

function Player:get_draw_position(): Point
	return self.position
end

global function new_hit_box(new_position: Point): Rectangle
    return Rectangle.new(new_position.x, new_position.y, BLOCK_SIZE, BLOCK_SIZE)
end

global record PlayerAnimation is Entity
	player: Player
	position: Point
	draw_position: Point
	animation: Animation
end

function PlayerAnimation.new(animation: Animation, player: Player): PlayerAnimation
	local self: PlayerAnimation = setmetatable({}, { __index = PlayerAnimation })
	self.animation = animation
	self.player = player
	self.position = player.position
	self.draw_position = player:get_draw_position()
	return self
end

local function block_to_anim_draw_pos(animation: Animation, pos: Point): Point
	-- y: +1 is because of the sprite, look over when doing animations
	return Point.new(
		pos.x + (BLOCK_SIZE - animation.width) / 2,
		pos.y - animation.height + BLOCK_SIZE + 1)
end

function PlayerAnimation:draw()
	if not self.player.is_alive then
		return
	end

	local draw_pos = block_to_anim_draw_pos(self.animation, self.draw_position)
	self.animation:draw(draw_pos.x, draw_pos.y)
end
