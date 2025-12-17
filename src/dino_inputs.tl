require("collision")
require("players")
local const = require("const")
local hitboxes = require("hitboxes")
local joysticks = require("joysticks")
local level_map = require("level_map")
local vectors = require("geometry.vectors")

local JOYPAD = joysticks.buttons()
local dino_inputs = {}

local function handle_jump_input(dt: number, player: Player, blocks_jump: Group<Kinematic>, lookup: Lookup)
	local function jump_is_possible(jump_to: Point): boolean
		local jump_landing_area = hitboxes.new_block(jump_to)
		
		-- Collision is done with hitboxes but here we care about
		-- movementboxes, check in an area around and then manually
		-- check for movementbox overlap
		local blocks_jumps_close = lookup:in_box_and_group(
			jump_landing_area:expand(const.BLOCK_SIZE), blocks_jump
		)
		
		for _, possible_jump_block in ipairs(blocks_jumps_close) do
			if jump_landing_area:overlap(possible_jump_block:movementbox()) then
				return false
			end
		end

		-- Finally check that jump area is contained in play area
		return level_map.player_area():contains(jump_landing_area)
	end

	local function try_all_jumps_for(jump_direction: Vector): Point | nil
		-- Try to jump as far as possible first
		for nbr_of_blocks_to_jump=player:get_max_jump_dist(), 1, -1 do
			local jump_to = player.position:move(
				jump_direction:scale(const.BLOCK_SIZE * nbr_of_blocks_to_jump)
			)
			local jump_candidates = {
				jump_to, level_map.snap_to_closest_grid_tile(jump_to)
			}

			for _, jump_candiated in ipairs(jump_candidates) do
				if jump_is_possible(jump_candiated) then
					return jump_candiated
				end
			end
		end

		return nil
	end

	local function get_jump_directions(): {Vector}
		local result: {Vector} = {}

		if lutro.joystick.isDown(player.id, JOYPAD.DOWN) then
			table.insert(result, vectors.new(0, 1))
		end
		if lutro.joystick.isDown(player.id, JOYPAD.UP) then
			table.insert(result, vectors.new(0, -1))
		end
		if lutro.joystick.isDown(player.id, JOYPAD.RIGHT) then
			table.insert(result, vectors.new(1, 0))
		end
		if lutro.joystick.isDown(player.id, JOYPAD.LEFT) then
			table.insert(result, vectors.new(-1, 0))
		end

		return result
	end

	local function get_jump_target(): Point | nil
		for _, jump_direction in ipairs(get_jump_directions()) do
			local jump_to = try_all_jumps_for(jump_direction)
			if jump_to then
				return jump_to
			end
		end
	end
	
	if lutro.joystick.isDown(player.id, JOYPAD.B) and player:can_jump() then
		local dino = player.dino
		dino.jump_powerup_for = dino.jump_powerup_for + dt
	end

	if (joysticks.is_released(player.id, JOYPAD.B) and player:can_jump()) or player:must_jump() then
		local jump_to = get_jump_target()
		player:jump_with_dino(jump_to)
	end
end

function dino_inputs.handle(dt: number, player: Player, blocks_jump: Group<Kinematic>, lookup: Lookup)
    handle_jump_input(dt, player, blocks_jump, lookup)
end

return dino_inputs