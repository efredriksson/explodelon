require("const")
require("geometry")
require("itertools")

global PLAYER_AREA = Rectangle.new(24, 32, 272, 176)

local function get_hard_blocks(): {Rectangle}
	local blocks: {Rectangle} = {}

	local function hard_block(i: number, j: number): Rectangle
		return Rectangle.new(
		    PLAYER_AREA.x + BLOCK_SIZE + i * 2 * BLOCK_SIZE,
			PLAYER_AREA.y + BLOCK_SIZE + j * 2 * BLOCK_SIZE,
			BLOCK_SIZE,
			BLOCK_SIZE
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

local function get_non_hard_block_positions(): {Point}
	local positions: {Point} = {}

	for i, j in double_loop_inner_loopback({0, 16}, {0, 10}) do
		local block = get_block_point(i, j)
		local is_hard_block = false
		for _, hard_block in ipairs(HARD_BLOCKS) do
			if hard_block.x == block.x and hard_block.y == block.y then
				is_hard_block = true
			end
		end

		if not is_hard_block then
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
