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
	jump_p: Point
	jump_v: Vector
	jump_target: Point
	jump_g: Vector
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

local function get_player_position_on_mount(original_pos: Point, direction: Direction): Point
	local horizonal_displacements: {Direction: integer} = {
		right = -5, left = 5, up = 0, down = 0,
	}
	local horizonal_displacement = horizonal_displacements[direction]
	local vertical_displacement = -8
	return original_pos:move(
		Vector.new(horizonal_displacement, vertical_displacement)
	)
end

-- Player jump constants 
local JUMP_TIME = 1.2              -- Unit: seconds
local JUMP_HEIGHT = 2 * BLOCK_SIZE -- Unit: pixels (not SI unit!)

local function get_init_jump_velocity(h_diff: number): number
	-- Derived from projectile equation, calculates initial velocity given the
	-- jump height (h_max - h_start) and the time the jump will take (constants)
	-- and the height difference of start and end position (h_diff).
	local h_max = JUMP_HEIGHT
	local t_end = JUMP_TIME
	return (2 / t_end) * (h_max + math.sqrt(h_max * (h_max + h_diff)))
end

local function get_gravity(init_velocity: number): number
	-- Calculates gravity from how the jump should look like. Not very physical
	-- but making up gravity coffecients that makes things look good is hard. 
	local h_max = JUMP_HEIGHT
	return init_velocity * init_velocity / (2 * h_max)
end

function Player:jumps_to(position: Point)
	if self.action ~= "jump" then
		self.action = "jump"
		self.jump_p = self.position
		self.jump_target = position

		local dino_target = get_player_position_on_mount(position, self.direction)
		local v_0 = get_init_jump_velocity(math.abs(dino_target.y - self.position.y))
		local g = get_gravity(v_0)
		local side_vel = (dino_target.x - self.position.x) / JUMP_TIME
		-- Y values for physics vectors are negative to match game coordinates:
		self.jump_v = Vector.new(side_vel, -v_0)
		self.jump_g = Vector.new(0, -g)
	end
end

function Player:update(dt: number)
	if self.action == "jump" then
		self.jump_p = self.jump_p:move(self.jump_v:scale(dt))
		self.jump_v = self.jump_v:minus(self.jump_g:scale(dt))
	
		local dino_target = get_player_position_on_mount(self.jump_target, self.direction)
		if self.jump_p:distance_to(dino_target) < 1 and self.jump_v.y > 0 then
			self.state = "mounted"
			self.action = "idle"
			self.position = self.jump_target
		end
	end
end

function Player:get_draw_position(): Point
	if self.action == "jump" then
		return self.jump_p
	elseif self.state == "mounted" then
		-- Adjust player sprite for being on top of its mount
		return get_player_position_on_mount(self.position, self.direction)
	end

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

global record MountedPlayerAnimation is Entity
	player: Player
	position: Point
	draw_position: Point
	player_animation: Animation
	dino_animation: Animation
end

function MountedPlayerAnimation.new(
	player_animation: Animation, dino_animation: Animation, player: Player
): MountedPlayerAnimation
	local self: MountedPlayerAnimation = setmetatable({}, { __index = MountedPlayerAnimation })
	self.player_animation = player_animation
	self.dino_animation = dino_animation
	self.player = player
	self.position = player.position
	self.draw_position = player:get_draw_position()
	return self
end

function MountedPlayerAnimation:draw()
	if not self.player.is_alive then
		return
	end

	local function draw(animation: Animation, pos: Point)
		local draw_pos = block_to_anim_draw_pos(animation, pos)
		animation:draw(draw_pos.x, draw_pos.y)
	end

	if self.player.direction == "down" then
		-- Need to draw dino in front of player walking towards screen
		draw(self.player_animation, self.draw_position)
		draw(self.dino_animation, self.player.position)
	else
		-- And player in front of dino in all other cases
		draw(self.dino_animation, self.player.position)
		draw(self.player_animation, self.draw_position)
	end
end
