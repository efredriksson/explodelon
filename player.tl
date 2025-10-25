require("const")
require("geometry")
require("animation")
require("entity")
require("dinos")
require("physics")
require("character_sprites")
require("hitboxes")

global type Action = enum
   "walk"
   "jump_on"
   "jump_off"
   "idle"
end

global type PlayerState = enum
	"foot"
	"mounted"
end

global record Player is Explodable, BlocksBombs
	id: integer
	sprite: CharacterSprite
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
	invulnerable_for: number
	dino: Dino
	jump_p: Point
	jump_v: Vector
	jump_g: Vector
	jump_target: Point
	jump_visual_target: Point
end

function Player.new(id: integer, sprite: CharacterSprite, position: Point): Player
	local self: Player = setmetatable({}, { __index = Player })
	self.id = id
	self.sprite = sprite
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
	self.invulnerable_for = 0
	self.dino = nil
	return self
end

function Player:get_position(): Point
	return self.position
end

function Player:hit_with_bomb()
	-- Stun of player not implemented
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

function Player:is_jumping(): boolean
	return self.action == "jump_on" or self.action == "jump_off"
end

function Player:is_riding_dino(): boolean
	return self.dino and not self.dino.hatching
end

function Player:is_invulnerable(): boolean
	return self.invulnerable_for > 0
end

function Player:accepts_input(): boolean
	return not self:is_jumping()
end

-- Player jump constants 
local JUMP_ON_TIME = 1.2               -- Unit: seconds
local JUMP_OFF_TIME = 0.9              -- Unit: seconds
local JUMP_ON_HEIGHT = 2 * BLOCK_SIZE  -- Unit: pixels (not SI unit!)
local JUMP_OFF_HEIGHT = 3 * BLOCK_SIZE -- Unit: pixels (not SI unit!)

function Player:_set_jump_v_and_g(jump_height: number, jump_time: number)
	local v_0 = get_init_projectile_velocity(
		math.abs(self.jump_visual_target.y - self.jump_p.y), jump_height, jump_time
	)
	local g = get_gravity(v_0, jump_height)
	local side_vel = (self.jump_visual_target.x - self.jump_p.x) / jump_time
	-- Y values for physics vectors are negative to match game coordinates:
	self.jump_v = Vector.new(side_vel, -v_0)
	self.jump_g = Vector.new(0, -g)
end

function Player:jumps_onto(dino: Dino)
	if not self:is_jumping() then
		self.action = "jump_on"
		self.state = "mounted"

		if self.dino then
			-- Jump in place when upgrading existing dino
			self.jump_target = self.position
			self.dino.action = "idle"
			self.dino:level_up()
			dino.level = 0 -- Dino is consumed into existing dino
		else
			self.jump_target = dino.position
			self.dino = dino
		end

		self.jump_p = self.position
		self.jump_visual_target = get_player_position_on_mount(self.jump_target, self.direction)
		self:_set_jump_v_and_g(JUMP_ON_HEIGHT, JUMP_ON_TIME)
	end
end

function Player:jump_off_dino()
	if not self:is_jumping() then
		self.action = "jump_off"
		self.state = "foot"

		self.jump_p = get_player_position_on_mount(self.position, self.direction)
		self.jump_target = self.position
		self.jump_visual_target = self.position
		self:_set_jump_v_and_g(JUMP_OFF_HEIGHT, JUMP_OFF_TIME)
	end
end

function Player:kill()
	if self:is_invulnerable() or self:is_jumping() then
		return
	end

	if self.dino then
		self.dino.action = "dying"
		self.dino = nil
		self.state = "foot"

		self.invulnerable_for = 2
		self:jump_off_dino()
		return
	end

	self.is_alive = false
end

function Player:blow_up()
	self:kill()
end

function Player:update(dt: number)
	self.invulnerable_for = self.invulnerable_for - dt

	if self:is_jumping() then
		self.jump_p = self.jump_p:move(self.jump_v:scale(dt))
		self.jump_v = self.jump_v:minus(self.jump_g:scale(dt))

		if self.jump_p:distance_to(self.jump_visual_target) < 1 and self.jump_v.y > 0 then
			self.action = "idle"
			self.position = self.jump_target
			if self.dino then
				self.dino.hatching = false
			end
		end
	end
end

function Player:set_movement(position: Point, direction: Direction)
	self.position = position
	self.direction = direction
	if self.dino then
		self.dino.position = position
		self.dino.direction = direction
	end
end

function Player:set_action(action: Action)
	self.action = action
	if self.dino then
		if action == "walk" then
			self.dino.action = "walk"
		elseif action == "idle" then
			self.dino.action = "idle"
		end
	end
end

function Player:get_draw_position(): Point
	if self:is_jumping() then
		return self.jump_p
	elseif self.state == "mounted" then
		-- Adjust player sprite for being on top of its mount
		return get_player_position_on_mount(self.position, self.direction)
	end

	return self.position
end

global record PlayerAnimation is Entity
	player: Player
	draw_position: Point
	animation: Animation
end

function PlayerAnimation.new(animation: Animation, player: Player): PlayerAnimation
	local self: PlayerAnimation = setmetatable({}, { __index = PlayerAnimation })
	self.animation = animation
	self.player = player
	self.draw_position = player:get_draw_position()
	return self
end

function PlayerAnimation:get_position(): Point
    return self.player.position
end

local function block_to_anim_draw_pos(animation: Animation, pos: Point): Point
	-- y: +1 is because of the sprite, look over when doing animations
	return Point.new(
		pos.x + (BLOCK_SIZE - animation.width) / 2,
		pos.y - animation.height + BLOCK_SIZE + 1)
end

function PlayerAnimation:draw()
	local draw_pos = block_to_anim_draw_pos(self.animation, self.draw_position)
	self.animation:draw(draw_pos.x, draw_pos.y)
	draw_hitbox(new_hitbox(self.player.position))
end

global record MountAnimation is Entity
	dino: Dino
	animation: Animation
end

function MountAnimation.new(animation: Animation, dino: Dino): MountAnimation
	local self: MountAnimation = setmetatable({}, { __index = MountAnimation })
	self.dino = dino
	self.animation = animation
	return self
end

function MountAnimation:get_position(): Point
    return self.dino.position
end

function MountAnimation:draw()
	local draw_pos = block_to_anim_draw_pos(self.animation, self.dino.position)
	self.animation:draw(draw_pos.x, draw_pos.y)
	draw_hitbox(new_hitbox(self.dino.position))
end

global record MountedPlayerAnimation is Entity
	player: Player
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
	self.draw_position = player:get_draw_position()
	return self
end

function MountedPlayerAnimation:get_position(): Point
    return self.player.position
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
	draw_hitbox(new_hitbox(self.player.position))
end
