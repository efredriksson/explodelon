require("const")
require("geometry")
require("itertools")

global PLAYER_AREA = Rectangle.new(24, 32, 272, 176)

local function get_hard_blocks(): {Point}
	local blocks: {Point} = {}

	local function hard_block(i: number, j: number): Point
		return Point.new(
		    PLAYER_AREA.x + BLOCK_SIZE + i * 2 * BLOCK_SIZE,
			PLAYER_AREA.y + BLOCK_SIZE + j * 2 * BLOCK_SIZE
		)
	end

	for i, j in double_loop_inner_loopback({0, 7}, {0, 4}) do
		table.insert(blocks, hard_block(i, j))
	end
	return blocks
end

global HARD_BLOCKS = get_hard_blocks()

local function get_block(i: number, j: number): Rectangle
	return Rectangle.new(
		PLAYER_AREA.x + i * BLOCK_SIZE,
		PLAYER_AREA.y + j * BLOCK_SIZE,
		BLOCK_SIZE,
		BLOCK_SIZE
	)
end

local function get_block_point(i: number, j: number): Point
	return get_block(i, j):top_left()
end

local function get_random_block(): Point
	return get_block_point(lutro.math.random(17) - 1, lutro.math.random(11) - 1)
end

local function is_hard_block_at(position: Point): boolean
	for _, hard_block in ipairs(HARD_BLOCKS) do
		if hard_block:equal(position) then
			return true
		end
	end

	return false
end

local function get_non_hard_block_positions(): {Point}
	local positions: {Point} = {}

	for i, j in double_loop_inner_loopback({0, 16}, {0, 10}) do
		local block = get_block_point(i, j)
		if not is_hard_block_at(block) then
			table.insert(positions, block)
		end
	end
	return positions
end

global NON_HARD_POSITIONS = get_non_hard_block_positions()

global function get_right_side_pressure_blocks(): {Point}
	local blocks: {Point} = {}

	for i, j in double_loop_inner_loopback({0, 3}, {0, 10}) do
		table.insert(blocks, get_block_point(i, j))
	end

	for j, i in double_loop_inner_loopback({0, 1}, {4, 12}) do
		table.insert(blocks, get_block_point(i, j))
	end

	return blocks
end

global function get_left_side_pressure_blocks(): {Point}
	local blocks: {Point} = {}

	for i, j in double_loop_inner_loopback({16, 13, -1}, {10, 0, -1}) do
		table.insert(blocks, get_block_point(i, j))
	end

	for j, i in double_loop_inner_loopback({10, 9, -1}, {12, 4, -1}) do
		table.insert(blocks, get_block_point(i, j))
	end

	return blocks
end

local function contains_position(list: {Point}, check_for: Point): boolean
	for _, elem in ipairs(list) do
		if elem:equal(check_for) then
			return true
		end
	end

	return false
end

local MAX_SOFT_BLOCKS = 105

global function get_soft_blocks(player_positions: {Point}): {Point}
	local soft_blocks: {Point} = {}
	local close_to_player: {Point} = {}

	for _, player_pos in ipairs(player_positions) do
		-- Do allow some positions close to player to have soft blocks:
		local sum_to_allow = lutro.math.random() < 0.5 and 2 or 0
		for j, i in double_loop_inner_loopback({-1, 1}, {-1, 1}) do
			if sum_to_allow ~= math.abs(i + j) or (i == 0 and j == 0) then
				local close_by = Vector.new(j, i):scale(BLOCK_SIZE)
				table.insert(close_to_player, player_pos:move(close_by))				
			end
		end
	end

	while #soft_blocks < MAX_SOFT_BLOCKS do
		local occupied = combine(HARD_BLOCKS, close_to_player, soft_blocks)
		local random_block = get_random_block()
		if not contains_position(occupied, random_block) then
			table.insert(soft_blocks, random_block)
		end
	end

	return soft_blocks
end

global function new_hit_box(new_position: Point): Rectangle
    return Rectangle.new(new_position.x, new_position.y, BLOCK_SIZE, BLOCK_SIZE)
end
