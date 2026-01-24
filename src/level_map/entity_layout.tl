local const = require("const")
local grid = require("level_map.grid")
local hitboxes = require("hitboxes")
local itertools = require("itertools")
local vectors = require("geometry.vectors")
local settings = require("settings")

local entity_layout = {}

global record HardBlockConfig
	position: Point
    tall: boolean
end

function HardBlockConfig.new(position: Point, tall: boolean): HardBlockConfig
    local self: HardBlockConfig = setmetatable({}, { __index = HardBlockConfig })
    self.position = position
    self.tall = tall
    return self
end

function entity_layout.get_hard_blocks(): {HardBlockConfig}
	local configs: {HardBlockConfig} = {}

	local function hard_block_config(i: number, j: number, tall: boolean): HardBlockConfig
		return HardBlockConfig.new(grid.get_tile_position(1 + i * 2, 1 + j * 2), tall)
	end

	for i, j in itertools.double_loop_inner_loopback({0, 7}, {0, 4}) do
		local is_tall = (j == 2 and (i == 1 or i == 6))
		table.insert(configs, hard_block_config(i, j, is_tall))
	end
	return configs
end

function entity_layout.get_hard_block_positions(): {Point}
	local configs = entity_layout.get_hard_blocks()
	local get_point = function (c: HardBlockConfig): Point return c.position end
	return itertools.map(configs, get_point)
end

local function is_hard_block_at(position: Point, hard_block_positions: {Point}): boolean
	for _, hard_block in ipairs(hard_block_positions) do
		if hard_block:equal(position) then
			return true
		end
	end

	return false
end

function entity_layout.get_non_hard_block_positions(): {Point}
	local positions: {Point} = {}
	local hard_blocks_positions = entity_layout.get_hard_block_positions()

	for i, j in itertools.double_loop_inner_loopback({0, 16}, {0, 10}) do
		local block = grid.get_tile_position(i, j)
		if not is_hard_block_at(block, hard_blocks_positions) then
			table.insert(positions, block)
		end
	end
	return positions
end


function entity_layout.get_right_side_pressure_blocks(): {Point}
	local blocks: {Point} = {}

	for i, j in itertools.double_loop_inner_loopback({0, 3}, {0, 10}) do
		table.insert(blocks, grid.get_tile_position(i, j))
	end

	for j, i in itertools.double_loop_inner_loopback({0, 1}, {4, 12}) do
		table.insert(blocks, grid.get_tile_position(i, j))
	end

	return blocks
end

function entity_layout.get_left_side_pressure_blocks(): {Point}
	local blocks: {Point} = {}

	for i, j in itertools.double_loop_inner_loopback({16, 13, -1}, {10, 0, -1}) do
		table.insert(blocks, grid.get_tile_position(i, j))
	end

	for j, i in itertools.double_loop_inner_loopback({10, 9, -1}, {12, 4, -1}) do
		table.insert(blocks, grid.get_tile_position(i, j))
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

global record SoftBlockConfig
	position: Point
    item: ItemType
    egg: boolean
end

function SoftBlockConfig.new(position: Point, item: ItemType, egg: boolean): SoftBlockConfig
    local self: SoftBlockConfig = setmetatable({}, { __index = SoftBlockConfig })
    self.position = position
    self.item = item
    self.egg = egg
    return self
end

local function get_soft_block_positions(occupies: {Kinematic}): {Point}
	local soft_blocks: {Point} = {}
	local close_to_entity: {Point} = {}
	local hard_block_positions = entity_layout.get_hard_block_positions()

	for _, occupied in ipairs(occupies) do
		-- Do allow some positions close to occupied entity to have soft blocks:
		local sum_to_allow = lutro.math.random() < 0.5 and 2 or 0
		for j, i in itertools.double_loop_inner_loopback({-1, 1}, {-1, 1}) do
			if sum_to_allow ~= math.abs(i + j) or (i == 0 and j == 0) then
				local close_by = vectors.new(j, i):scale(const.BLOCK_SIZE)
				table.insert(close_to_entity, occupied:get_position():move(close_by))
			end
		end
	end

	while #soft_blocks < settings.game_rules.items.nbr_soft_blocks do
		local occupied = itertools.combine(hard_block_positions, close_to_entity, soft_blocks)
		local random_block = grid.get_random_tile()
		if not contains_position(occupied, random_block) then
			table.insert(soft_blocks, random_block)
		end
	end

	return soft_blocks
end

function entity_layout.get_soft_blocks(occupied: {Kinematic}): {SoftBlockConfig}
	local item_settings = settings.game_rules.items
	local soft_blocks: {SoftBlockConfig} = {}

	local blocks_positions = get_soft_block_positions(occupied)
	for item_type, quantity in pairs(item_settings.nbr_of_items) do
		for _=1, math.min(quantity, #blocks_positions) do
			local pos = table.remove(blocks_positions, 1)
			table.insert(soft_blocks, SoftBlockConfig.new(pos, item_type, false))
		end
	end
	for _=1, math.min(settings.game_rules.dinos.nbr_of_eggs, #blocks_positions) do
		local pos = table.remove(blocks_positions, 1)
		table.insert(soft_blocks, SoftBlockConfig.new(pos, nil, true))
	end
	for _, pos in ipairs(blocks_positions) do
		table.insert(soft_blocks, SoftBlockConfig.new(pos, nil, false))
	end

	return soft_blocks
end

function entity_layout.get_player_start_positions(number_of_players: integer): {Point}
	local x_min = 0
	local x_max = 16
	local y_min = 0
	local y_max = 10

	local corners = {
		grid.get_tile_position(x_min, y_min),
		grid.get_tile_position(x_max, y_max),
		grid.get_tile_position(x_max, y_min),
		grid.get_tile_position(x_min, y_max)
	}
	local center = {grid.get_tile_position(x_max / 2, y_max / 2)}
	local inner_positions = {
		grid.get_tile_position(x_min + 5, y_min + 2),
		grid.get_tile_position(x_max - 5, y_max - 2),
		grid.get_tile_position(x_max - 5, y_min + 2),
		grid.get_tile_position(x_min + 5, y_max - 2)
	}

	local function get_positions(): {Point}
		if number_of_players == 5 then
			-- Only if there are 5 players can you start dead in the middle
			return itertools.combine(corners, center)
		else
			local result = itertools.combine(corners, inner_positions)
			return {table.unpack(result, 1, number_of_players)}
		end
	end

	if settings.game_rules.players.start_position_shuffle then
		return itertools.shuffle(get_positions())
	else
		return get_positions()
	end
end

global record Goal
	position: Point
	pair: Point
end

function Goal.new(position: Point, pair: Point): Goal
   local self: Goal = setmetatable({}, { __index = Goal })
   self.position = position
   self.pair = pair
   return self
end

function Goal:get_hitbox(): Rectangle
	return hitboxes.new_block(self.position)
end

function entity_layout.get_goals(): {Goal}
	if settings.map ~= "football" then
		return {}
	end

	return {
		Goal.new(grid.get_tile_position(-1, 4), grid.get_tile_position(-1, 6)),
		Goal.new(grid.get_tile_position(-1, 6), grid.get_tile_position(-1, 4)),
		Goal.new(grid.get_tile_position(17, 4), grid.get_tile_position(17, 6)),
		Goal.new(grid.get_tile_position(17, 6), grid.get_tile_position(17, 4)),
	}
end

global record ConveyorBelt
	position: Point
	direction: Vector
end

function ConveyorBelt.new(position: Point, direction: Vector): ConveyorBelt
   local self: ConveyorBelt = setmetatable({}, { __index = ConveyorBelt })
   self.position = position
   self.direction = direction
   return self
end

function ConveyorBelt:get_hitbox(): Rectangle
	return hitboxes.new_block(self.position)
end

function entity_layout.get_conveyor_belts(): {ConveyorBelt}
	if settings.map ~= "factory" then
		return {}
	end

	local function create_belt(i: integer, j: integer, dir: Direction): ConveyorBelt
		return ConveyorBelt.new(grid.get_tile_position(i, j), vectors.from_direction(dir))
	end

    local dim = grid.dimensions()
	return {
		-- Outer ring
		create_belt(dim.x_min, dim.y_min, "down"),
		create_belt(dim.x_max, dim.y_max, "up"),
		create_belt(dim.x_max, dim.y_min, "left"),
		create_belt(dim.x_min, dim.y_max, "right"),
		-- Middle ring
		create_belt(dim.x_min + 4, dim.y_min + 2, "right"),
		create_belt(dim.x_max - 4, dim.y_max - 2, "left"),
		create_belt(dim.x_max - 4, dim.y_min + 2, "down"),
		create_belt(dim.x_min + 4, dim.y_max - 2, "up"),
		-- Inner ring
		create_belt(dim.x_min + 6, dim.y_min + 4, "down"),
		create_belt(dim.x_max - 6, dim.y_max - 4, "up"),
		create_belt(dim.x_max - 6, dim.y_min + 4, "left"),
		create_belt(dim.x_min + 6, dim.y_max - 4, "right"),
		-- Middle up/down
		create_belt(math.ceil(dim.x_max / 2), dim.y_min, "down"),
		create_belt(math.ceil(dim.x_max / 2), dim.y_max, "up"),
	}
end

return entity_layout
