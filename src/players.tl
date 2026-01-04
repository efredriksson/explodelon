require("animations")
require("characters")
require("dinos")
require("entity")
local const = require("const")
local hitboxes = require("hitboxes")
local physics = require("physics")
local vectors = require("geometry.vectors")
local settings = require("settings")

local SLIDE_FOR_TIME = 0.4
local CHARACTER_HEIGHT_ON_DINO = 8 -- How high up from ground player is when on dino
local DASH_WITH_DINO_SPEED_BONUS = {
	[1] = 50,
	[2] = 70,
	[3] = 90,
}

global type Action = enum
   "walk"
   "jump_on"
   "jump_off"
   "jump"
   "idle"
   "dying"
   "stunned"
   "dash"
   "crashed"
   "slide"
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
	slide_for: number
	dino: Dino

	jump_trajectory: ProjectileTrajectory
	jump_target: Point
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
	self.slide_for = 0
	self.dino = nil
	return self
end

function Player:get_position(): Point
	return self.position
end

function Player:draw()
	assert(false, "Not implemented")
end

function Player:is_jumping_on_off_dino(): boolean
	return self.action == "jump_on" or self.action == "jump_off"
end

function Player:is_jumping(): boolean
	return self:is_jumping_on_off_dino() or self.action == "jump"
end

function Player:is_stunned(): boolean
	return self.stunned_for > 0
end

function Player:can_slide(): boolean
	return self.action == "dash" and self.dino and self.dino.level >= 2
end

function Player:is_sliding(): boolean
	return self.slide_for > 0
end

function Player:set_action(action: Action)
	if self.action == "dying" or self:is_stunned() or self:is_sliding() then
		-- Not able to perform new action due to conditions
		return
	end

	if self.action == "dash" and (action == "walk" or action == "idle") then
		-- Not possible to exit dash action into walk or idle
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
		elseif action == "jump" then
			self.dino.action = "jump"
		elseif action == "dash" then
			self.dino.action = "dash"
		elseif action == "crashed" then
			self.dino.action = "crashed"
		elseif action == "slide" then
			self.dino.action = "slide"
		end
	end
end

function Player:set_movement(position: Point, direction: Direction)
	if self.action == "dash" and self.position:equal(position) then

		self:set_action("crashed")
		if self.dino and self.dino.level == 1 then
			self.stunned_for = 1.2
		end

		return
	end

	self.position = position
	self.direction = direction
	if self.dino then
		self.dino.position = position
		self.dino.direction = direction
	end
end

function Player:slide_with_dino()
	self:set_action("slide")
	self.slide_for = SLIDE_FOR_TIME
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

local function get_character_on_dino_ground_position(original_pos: Point, direction: Direction): Point
	local horizonal_displacements: {Direction: integer} = {
		right = -5, left = 5, up = 0, down = 0,
	}
	local horizonal_displacement = horizonal_displacements[direction]
	return original_pos:move(
		vectors.new(horizonal_displacement, 0)
	)
end

local function get_character_position_on_top_of_dino(original_pos: Point, direction: Direction): Point
	local to_the_side_pos = get_character_on_dino_ground_position(original_pos, direction)
	return to_the_side_pos:move(vectors.new(0, -CHARACTER_HEIGHT_ON_DINO))
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

function Player:jumps_onto(dino: Dino)
	if not self:is_jumping() then
		self:set_action("jump_on")
		self.state = "mounted"
		local character_distance_over_ground = 0.0

		if self.dino then
			-- Jump in place when upgrading existing dino
			self.dino.action = "idle"
			self.dino:level_up()
			dino.level = 0 -- Dino is consumed into existing dino
			character_distance_over_ground = CHARACTER_HEIGHT_ON_DINO
		else
			self.dino = dino
		end

		local character_ground_pos = get_character_on_dino_ground_position(self.dino.position, self.direction)
		self.jump_trajectory = physics.calc_trajectory(
			character_distance_over_ground,
			CHARACTER_HEIGHT_ON_DINO,
			JUMP_ON_HEIGHT,
			JUMP_ON_TIME,
			self.position,
			character_ground_pos
		)
		self.jump_target = self.dino.position
	end
end

function Player:jump_off_dino()
	if not self:is_jumping() then
		self:set_action("jump_off")
		self.state = "foot"

		self.jump_target = self.position
		-- Set current position as shifted by riding dino to jump from that position
		self.position = get_character_on_dino_ground_position(self.position, self.direction)
		self.jump_trajectory = physics.calc_trajectory(
			CHARACTER_HEIGHT_ON_DINO, 0, JUMP_OFF_HEIGHT, JUMP_OFF_TIME, self.position, self.jump_target
		)
	end
end

local DINO_POWERUP_TIME_INTERVAL = 0.2

function Player:can_jump(): boolean
	return self.dino and self.dino.color == "pink" and not self:is_jumping()
end

function Player:get_max_jump_dist(): integer
	local jump_dist = 2 * (math.floor(self.dino.jump_powerup_for / DINO_POWERUP_TIME_INTERVAL) + 1)
	-- Clamp max jump dist
	return math.min(jump_dist, self.dino.level * 2)
end

function Player:_get_max_jump_powerup_time(): number
	return self.dino.level * DINO_POWERUP_TIME_INTERVAL
end

function Player:must_jump(): boolean
	return self.dino and self.dino.jump_powerup_for > self:_get_max_jump_powerup_time()
end

function Player:jump_with_dino(jump_to: Point | nil)
	if self.dino and self.dino.color == "pink" and not self:is_jumping() then
		self:set_action("jump")
		
		self.jump_target = jump_to or self.position
		local dino_jump_time = {
			[1] = 0.9,
			[2] = 1.0,
			[3] = 1.1,
			[4] = 1.2,
			[5] = 1.3,
			[6] = 1.4,
		}
		local dino_jump_height = {
			[1] = 1.2 * const.BLOCK_SIZE,
			[2] = 1.4 * const.BLOCK_SIZE,
			[3] = 1.7 * const.BLOCK_SIZE,
			[4] = 2.0 * const.BLOCK_SIZE,
			[5] = 2.3 * const.BLOCK_SIZE,
			[6] = 2.6 * const.BLOCK_SIZE,
		}
		local jump_power = self:get_max_jump_dist()
		assert(jump_power <= 6 and jump_power >= 1)
		self.jump_trajectory = physics.calc_trajectory(
			0,
			0,
			dino_jump_height[jump_power],
			dino_jump_time[jump_power],
			self.position,
			self.jump_target
		)
		self.dino.jump_powerup_for = 0
	end
end

function Player:dash_with_dino()
	self:set_action("dash")
end

function Player:get_speed(): number
	if self.action == "dash" and self.dino then
		return self.speed + DASH_WITH_DINO_SPEED_BONUS[self.dino.level]
	elseif self.action == "slide" then
		return self.speed * (self.slide_for / SLIDE_FOR_TIME)
	else
		return self.speed
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

function Player:get_jump_position(): Point
	return self.jump_trajectory:in_air_position(self.position)
end

function Player:update(dt: number)
	self.invulnerable_for = self.invulnerable_for - dt
	self.stunned_for = self.stunned_for - dt
	self.slide_for = self.slide_for - dt

	if self.action == "stunned" or self.action == "slide" then
		self:set_action("idle") -- Try to transition from stunned/slide
	end

	if self:is_jumping() then
		self.position = self.jump_trajectory:update(dt, self.position)
		if self.jump_trajectory:finished() then
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
	if self:is_jumping_on_off_dino() then
		return self:get_jump_position()
	elseif self.action == "jump" then
		-- Adjust player sprite for jump height and being on top of its mount
		return get_character_position_on_top_of_dino(self:get_jump_position(), self.direction)
	elseif self.state == "mounted" then
		-- Adjust player sprite for being on top of its mount
		return get_character_position_on_top_of_dino(self.position, self.direction)
	end

	return self.position
end

return players
