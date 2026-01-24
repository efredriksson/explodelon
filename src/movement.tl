require("players")
require("bombs")
require("lightning_bombs")
local const = require("const")
local grid = require("level_layout.grid")
local joysticks = require("joysticks")
local vectors = require("geometry.vectors")

local JOYPAD = joysticks.buttons()

local record Movement
	dxdy: Vector
	dir: Direction
end

function Movement.new(dxdy: Vector, dir: Direction): Movement
	local self: Movement = setmetatable({}, { __index = Movement })
	self.dir = dir
	self.dxdy = dxdy
	return self
end

function Movement.new_from_player(dt: number, player: Player): Movement
   	local self: Movement = setmetatable({}, { __index = Movement })
   	self.dir = player.direction
	self.dxdy = vectors.from_direction(self.dir):scale(dt * player:get_speed())
	return self
end

local record CheckedMovement
	position: Point
	spent: boolean
	cuts_corner: boolean
end

function CheckedMovement.new(
	position: Point, spent: boolean, cuts_corner: boolean
): CheckedMovement
   local self: CheckedMovement = setmetatable({}, { __index = CheckedMovement })
   self.position = position
   self.spent = spent
   self.cuts_corner = cuts_corner
   return self
end

local function get_moves_from_input(player: Player, dt: number): {Movement}
	local result: {Movement} = {}

	if lutro.joystick.isDown(player.id, JOYPAD.DOWN) then
		table.insert(result, Movement.new(vectors.new(0, dt * player:get_speed()), "down"))
	end
	if lutro.joystick.isDown(player.id, JOYPAD.UP) then
		table.insert(result, Movement.new(vectors.new(0, -dt * player:get_speed()), "up"))
	end
	if lutro.joystick.isDown(player.id, JOYPAD.RIGHT) then
		table.insert(result, Movement.new(vectors.new(dt * player:get_speed(), 0), "right"))
	end
	if lutro.joystick.isDown(player.id, JOYPAD.LEFT) then
		table.insert(result, Movement.new(vectors.new(-dt * player:get_speed(), 0), "left"))
	end

	return result
end

--- Sign of a number represented as 1 or -1
local function sign_of(number: number): integer
	return number > 0 and 1 or (number == 0 and 0 or -1)
end

--- Split movement that goes against block into parts for walking corner.
-- If at just the corner the movement length will be split so the returned
-- vector represents moving up to the corner and then down the corner with
-- what is left. Signs of movement are handled but it is always assumed that
-- we are walking against the wall on the y-axis. If this is not the case
-- the vector returned have to be permutated.
local function around_corner_move(
	movement_len: number, dist_to_corner: number, pos_and_block_lateral_diff: number
): Vector
	local movement_dist = math.abs(movement_len)
	local movement_towards_corner = math.min(dist_to_corner, movement_dist)
	local movement_down_corner = movement_dist - movement_towards_corner

	return vectors.new(
		sign_of(pos_and_block_lateral_diff) * movement_towards_corner,
		sign_of(movement_len) * movement_down_corner
	)
end

local function in_corridor_and_walking_against_wall(
	position: Point, walk_dir: Direction
): boolean
	local local_pos = grid.get_local_tile_position(position)
	local in_vertical_corridor = local_pos.x == 0 and local_pos.y > 0
	local in_horizontal_corridor = local_pos.y == 0 and local_pos.x > 0

	return (in_vertical_corridor and (walk_dir == "left" or walk_dir == "right")) or
		(in_horizontal_corridor and (walk_dir == "up" or walk_dir == "down"))
end

local function in_end_of_corridor_and_walking_out(
	movement: Movement, player_pos: Point
): boolean
	local local_pos = grid.get_local_tile_position(player_pos)

	local function first_half_of_block(val: number): boolean
		return val < const.BLOCK_SIZE / 2 and val > 0
	end
	local function second_half_of_block(val: number): boolean
		return val > const.BLOCK_SIZE / 2
	end

	return (movement.dir == "down" and second_half_of_block(local_pos.y)) or
		(movement.dir == "up" and first_half_of_block(local_pos.y)) or
		(movement.dir == "right" and second_half_of_block(local_pos.x)) or
		(movement.dir == "left" and first_half_of_block(local_pos.x))
end

local function restrict_player_movement(
	player: Player,
	movement: Vector,
	blocking_blocks: {Kinematic},
	hard_blocks: {Kinematic},
	lightning_bombs: LightningBombs,
	blocks_bombs: Group<Kinematic>,
	players: Group<Player>,
	bombs: Group<Bomb>,
	lookup: Lookup
): CheckedMovement
	local margin_for_corner_assist = 8
	local new_position = player.position:move(movement)
	local new_hitbox = player:movementbox():shift(movement)

	local function move_against_block(
		movement_len: number,
		pos_and_block_lateral_diff: number,
		walk_along_y_axis: boolean
	): CheckedMovement
		local dist_to_corner = const.BLOCK_SIZE - math.abs(pos_and_block_lateral_diff)

		if dist_to_corner > margin_for_corner_assist then
			return CheckedMovement.new(player.position, false, false)
		end

		local along_wall = around_corner_move(
			movement_len, dist_to_corner, pos_and_block_lateral_diff
		):permutate_if(walk_along_y_axis)

		-- Using 'new_position' instead of 'player_pos' here is not a bug, this
		-- actuall makes corner movement smoother and feel much better.
		-- It also makes so you move over the corner, i.e 'cutting the corner'
		return CheckedMovement.new(new_position:move(along_wall), true, true)
	end

	local old_hitbox = player:movementbox()
	local function walking_further_into_block(block: Rectangle): boolean
		if not new_hitbox:overlap(block) then
			return false
		end

		local new_dist_to_1_ton_block = block:center_distance(new_hitbox)
		local old_dist_to_1_ton_block = block:center_distance(old_hitbox)
		return new_dist_to_1_ton_block < old_dist_to_1_ton_block
	end

	for _, bomb in ipairs(lookup:in_box_and_group(player:movementbox():expand(const.BLOCK_SIZE), bombs)) do
		local bomb_hitbox = bomb:movementbox()
		if walking_further_into_block(bomb_hitbox) then
			if bomb.position:distance_to(player.position) > const.BLOCK_SIZE * (3 / 4) or bomb.has_been_kicked then
				-- If a bomb has been kicked then it is no longer to move
				-- freely in far inside it. This is to stop moving through
				-- bombs that are kicked against a player.
				local kick_direction = movement:normalize()
				if player.has_kick then
					local can_move = bomb:can_move(
						kick_direction:scale(const.BLOCK_SIZE), blocks_bombs, players, bombs, lookup
					)
					if can_move.yes then
						-- Walking into bomb and at edge of bomb then kick
						bomb:kick(can_move.in_direction)
					end
				end
				-- Not allowed to walk further into bomb if at edge
				return CheckedMovement.new(player.position, false, false)
			end
		end
	end

	for _, bomb in ipairs(lightning_bombs.on_ground) do
		local bomb_hitbox = bomb:movementbox()
		if walking_further_into_block(bomb_hitbox) then
			if bomb.position:distance_to(player.position) > const.BLOCK_SIZE * (3 / 4) then
				-- Not allowed to walk further into bomb if at edge
				return CheckedMovement.new(player.position, false, false)
			end
		end
	end

	for _, block in ipairs(blocking_blocks) do
		if walking_further_into_block(block:movementbox()) then
			-- Not allowed to walk further into 1 ton block
			return CheckedMovement.new(player.position, false, false)
		end
	end

	for _, block in ipairs(hard_blocks) do
		local block_box = block:movementbox()
		if new_hitbox:overlap(block_box) then
			if movement.x == 0 then
				local movement_len = movement.y
				local pos_and_block_lateral_diff = player.position.x - block_box.x
				local walk_along_y_axis = false
				return move_against_block(
					movement_len, pos_and_block_lateral_diff, walk_along_y_axis
				)
			elseif movement.y == 0 then
				local movement_len = movement.x
				local pos_and_block_lateral_diff = player.position.y - block_box.y
				local walk_along_y_axis = true
				return move_against_block(
					movement_len, pos_and_block_lateral_diff, walk_along_y_axis
				)
			else
				assert(false, "Bad movement vector")
			end
		end
	end

	if not grid.area():contains(new_hitbox) then
		local clamped_position = grid.area():clamp(new_hitbox):top_left()
		return CheckedMovement.new(clamped_position, false, false)
	end

	return CheckedMovement.new(new_position, true, false)
end


local function get_new_player_orientation(
	player_dir: Direction,
	directions: {Movement},
	blocking_blocks: {Kinematic},
	hard_blocks: {Kinematic},
	lightning_bombs: LightningBombs,
	player: Player,
	blocks_bombs: Group<Kinematic>,
	players: Group<Player>,
	bombs: Group<Bomb>,
	lookup: Lookup
): Direction, Point

	--- Get movment priority, lower number is higher priority.
	-- For example walking out of corridor and cutting corner
	-- have a low priority and should be tried last. This is
	-- mainly to sort and handle all cases when the user press multiple
	-- directions in a deterministic and expected way.
	local function movement_prio(movement: Movement): integer
		local move_if_done = restrict_player_movement(
			player, movement.dxdy, blocking_blocks, hard_blocks, lightning_bombs, blocks_bombs, players, bombs, lookup
		)

		if in_end_of_corridor_and_walking_out(movement, player.position) then
			return 4
		elseif move_if_done.cuts_corner then
			return 3
		elseif in_corridor_and_walking_against_wall(player.position, movement.dir) then
			return 2
		else
			return 1
		end
	end

	local function sort_directions_by_prio(to_sort: {Movement})
		local function compare(m1: Movement, m2: Movement): boolean
			return movement_prio(m1) < movement_prio(m2)
		end
		table.sort(to_sort, compare)
	end

	local cur_position = player.position
	local cur_direction = player_dir

	sort_directions_by_prio(directions)
	for _, direction in ipairs(directions) do
		local movement = restrict_player_movement(
			player, direction.dxdy, blocking_blocks, hard_blocks, lightning_bombs, blocks_bombs, players, bombs, lookup
		)
		cur_position = movement.position
		cur_direction = direction.dir

		if movement.spent then
			break -- All speed have been used up!
		end
	end
	return cur_direction, cur_position
end

local movement = {}
local INVERTED_DIRECTIONS: {Direction: Direction} = {
	up = "down",
	down = "up",
	left = "right",
	right = "left"
}

local function inputs_for_sliding(player: Player, move_inputs: {Movement}): boolean
	for _, move in ipairs(move_inputs) do
		if move.dir == INVERTED_DIRECTIONS[player.direction] then
			return true
		end
	end

	return false
end

local function get_moves(player: Player, move_inputs: {Movement}, momentum: Movement): {Movement}
	if player.action == "slide" then
		return {momentum}
	elseif player.action == "dash" then
		if player.dino and player.dino.level >= 3 then
			-- For level 3 dinos then check if direction is changed which is
			-- allowed for highest level dino

			for _, move in ipairs(move_inputs) do
				if move.dir ~= player.direction then
					-- Also return move to continue with dash which will be used
					-- if changing direction does not work
					return {move, momentum}
				end
			end
		end
		
		return {momentum}
	else
		return move_inputs
	end
end

function movement.set_position_and_dir_from_input(
	player: Player,
	dt: number,
	blocking_blocks: {Kinematic},
	hard_blocks: {Kinematic},
	lightning_bombs: LightningBombs,
	blocks_bombs: Group<Kinematic>,
	players: Group<Player>,
	bombs: Group<Bomb>,
	lookup: Lookup
)
	local move_inputs = get_moves_from_input(player, dt)

	if player:can_slide() and inputs_for_sliding(player, move_inputs) then
		player:slide_with_dino()
	end

	local momentum = Movement.new_from_player(dt, player)
	local moves = get_moves(player, move_inputs, momentum)

	local new_dir, new_pos = get_new_player_orientation(
		player.direction, moves, blocking_blocks, hard_blocks, lightning_bombs, player, blocks_bombs, players, bombs, lookup
	)
	player:set_movement(new_pos, new_dir)
	if #moves == 0 then
		player:set_action("idle")
	else
		player:set_action("walk")
	end
end

return movement
