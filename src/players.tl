require("animations")
require("characters")
require("dinos")
require("entity")
local const = require("const")
local hitboxes = require("hitboxes")
local physics = require("physics")
local vectors = require("geometry.vectors")
local settings = require("settings")


global type Action = enum
   "walk"
   "jump_on"
   "jump_off"
   "idle"
   "dying"
   "stunned"
end

global type PlayerState = enum
	"foot"
	"mounted"
end

global record Player is Explodable, Kinematic, Entity
	id: integer
	sprite: CharacterName
   	position: Point
	direction: Direction
	action: Action
	state: PlayerState
	is_removed: boolean
	speed: integer
	bombs: integer
	lightning_bomb: integer
	fire: integer
	has_kick: boolean
	invulnerable_for: number
	stunned_for: number
	dino: Dino
	jump_p: Point
	jump_v: Vector
	jump_g: Vector
	jump_target: Point
	jump_visual_target: Point
end

local players = {}

function players.new(id: integer, sprite: CharacterName, position: Point): Player
	local self: Player = setmetatable({}, { __index = Player })
	self.id = id
	self.sprite = sprite
	self.position = position
	self.direction = "down"
	self.action = "idle"
	self.state = "foot"
	self.is_removed = false
	local player_settings = settings.game_rules.players
	self.speed = player_settings.start_speed
	self.has_kick = player_settings.start_with_kick
	self.bombs = player_settings.start_with_bombs
	self.lightning_bomb = player_settings.start_with_lightning_bombs
	self.fire = player_settings.start_with_fire
	self.invulnerable_for = 0
	self.stunned_for = 0
	self.dino = nil
	return self
end

function Player:get_position(): Point
	return self.position
end

function Player:draw()
	assert(false, "Not implemented")
end

function Player:set_movement(position: Point, direction: Direction)
	self.position = position
	self.direction = direction
	if self.dino then
		self.dino.position = position
		self.dino.direction = direction
	end
end

function Player:is_stunned(): boolean
	return self.stunned_for > 0
end

function Player:set_action(action: Action)
	if self.action == "dying" or self:is_stunned() then
		-- Not able to perform new action due to conditions
		return
	end

	self.action = action
	if self.dino then
		if action == "walk" then
			self.dino.action = "walk"
		elseif action == "idle" then
			self.dino.action = "idle"
		elseif action == "stunned" then
			self.dino.action = "stunned"
		end
	end
end

function Player:stun_for(duration: integer)
	self:set_action("stunned")
	self.stunned_for = duration
	self.direction = "down"
end

function Player:hit_with_bomb()
	self:stun_for(1)
end

function Player:hitbox(): Rectangle
	-- This hitbox is not for movement
	return hitboxes.new_block(self.position):shrink(4)
end

function Player:movementbox(): Rectangle
	return hitboxes.new_block(self.position)
end

local function get_player_position_on_mount(original_pos: Point, direction: Direction): Point
	local horizonal_displacements: {Direction: integer} = {
		right = -5, left = 5, up = 0, down = 0,
	}
	local horizonal_displacement = horizonal_displacements[direction]
	local vertical_displacement = -8
	return original_pos:move(
		vectors.new(horizonal_displacement, vertical_displacement)
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
	return not self:is_jumping() and not self:is_stunned() 
end

-- Player jump constants 
local JUMP_ON_TIME = 1.2               		 -- Unit: seconds
local JUMP_OFF_TIME = 0.9              		 -- Unit: seconds
local JUMP_ON_HEIGHT = 2 * const.BLOCK_SIZE  -- Unit: pixels (not SI unit!)
local JUMP_OFF_HEIGHT = 3 * const.BLOCK_SIZE -- Unit: pixels (not SI unit!)

function Player:_set_jump_v_and_g(jump_height: number, jump_time: number)
	local v_0 = physics.calc_init_projectile_velocity(
		math.abs(self.jump_visual_target.y - self.jump_p.y), jump_height, jump_time
	)
	local g = physics.calc_gravity(v_0, jump_height)
	local side_vel = (self.jump_visual_target.x - self.jump_p.x) / jump_time
	-- Y values for physics vectors are negative to match game coordinates:
	self.jump_v = vectors.new(side_vel, -v_0)
	self.jump_g = vectors.new(0, -g)
end

function Player:jumps_onto(dino: Dino)
	if not self:is_jumping() then
		self:set_action("jump_on")
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
		self:set_action("jump_off")
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

	self.action = "dying"
end

function Player:remove()
	self.is_removed = true
	self.action = "dying"
end

function Player:blow_up()
	self:kill()
end

function Player:is_alive(): boolean
	return self.action ~= "dying"
end

function Player:update(dt: number)
	self.invulnerable_for = self.invulnerable_for - dt
	self.stunned_for = self.stunned_for - dt
	if self.action == "stunned" then
		self:set_action("idle") -- Try to transition from stunned
	end

	if self:is_jumping() then
		local previous_distance = self.jump_p:distance_to(self.jump_visual_target)
		local falling = self.jump_v.y > 0

		self.jump_p = self.jump_p:move(self.jump_v:scale(dt))
		self.jump_v = self.jump_v:minus(self.jump_g:scale(dt))

		local new_distance = self.jump_p:distance_to(self.jump_visual_target)
		if new_distance >= previous_distance and falling then
			-- When distance from target not decreasing while falling we have landed
			self:set_action("idle")
			self.position = self.jump_target
			if self.dino then
				self.dino.hatching = false
			end
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

return players
