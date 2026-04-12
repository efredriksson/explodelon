local points = require("engine.geometry.points")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local entities = require("level_layout.maps.entities")
local maps = require("level_layout.maps.init")
local settings = require("settings")

local type Kinematic = require("kinematic")
local type Point = points.Point
local type Goal = entities.Goal
local type ConveyorBelt = entities.ConveyorBelt
local type ItemType = settings.ItemType
local type BlockType = entities.BlockType

local record HardBlockConfig
    position: Point
    is_tall: boolean
end

local record SoftBlockConfig
    position: Point
    item: ItemType
    egg: boolean
end

local record BlockConfigs
    hard: {HardBlockConfig}
    soft: {SoftBlockConfig}
    non_hard: {Point}
end

function HardBlockConfig.new(position: Point, is_tall: boolean): HardBlockConfig
    local self: HardBlockConfig = setmetatable({}, {__index = HardBlockConfig})
    self.position = position
    self.is_tall = is_tall
    return self
end

function SoftBlockConfig.new(
    position: Point, item: ItemType, egg: boolean
): SoftBlockConfig
    local self: SoftBlockConfig = setmetatable({}, {__index = SoftBlockConfig})
    self.position = position
    self.item = item
    self.egg = egg
    return self
end

local map_entities = {
    SoftBlockConfig = SoftBlockConfig,
    HardBlockConfig = HardBlockConfig,
    BlockConfigs = BlockConfigs,
}

local function assign_items_to_positions(blocks_positions: {Point}): {SoftBlockConfig}
    local item_settings = settings.game_rules.items
    local soft: {SoftBlockConfig} = {}
    -- Shuffle so items are assigned randomly to blocks
    blocks_positions = itertools.shuffle(blocks_positions)
    for item_type, quantity in pairs(item_settings.nbr_of_items) do
        for _ = 1, math.min(quantity, #blocks_positions) do
            local pos = table.remove(blocks_positions, 1)
            table.insert(soft, SoftBlockConfig.new(pos, item_type, false))
        end
    end
    for _ = 1, math.min(settings.game_rules.dinos.nbr_of_eggs, #blocks_positions) do
        local pos = table.remove(blocks_positions, 1)
        table.insert(soft, SoftBlockConfig.new(pos, nil, true))
    end
    for _, pos in ipairs(blocks_positions) do
        table.insert(soft, SoftBlockConfig.new(pos, nil, false))
    end
    return soft
end

function BlockConfigs.new(
    hard: {HardBlockConfig}, soft: {SoftBlockConfig}, non_hard: {Point}
): BlockConfigs
    local self: BlockConfigs = setmetatable({}, {__index = BlockConfigs})
    self.hard = hard
    self.soft = soft
    self.non_hard = non_hard
    return self
end

function map_entities.get_block_configs(occupied: {Kinematic}): BlockConfigs
    local layout = maps.get_layout():get_block_layout(occupied)
    local dim = grid.dimensions()
    local hard: {HardBlockConfig} = {}
    local soft_positions: {Point} = {}
    local non_hard: {Point} = {}
    for i = 0, dim.x_max do
        for j = 0, dim.y_max do
            local cell: BlockType = layout[i][j]
            local pos = grid.get_tile_position(i, j)
            if cell == "hard" or cell == "hard_tall" then
                table.insert(hard, HardBlockConfig.new(pos, cell == "hard_tall"))
            else
                table.insert(non_hard, pos)
                if cell == "soft" then
                    table.insert(soft_positions, pos)
                end
            end
        end
    end
    return BlockConfigs.new(hard, assign_items_to_positions(soft_positions), non_hard)
end

function map_entities.get_right_side_pressure_blocks(): {Point}
    local blocks: {Point} = {}

    for i, j in itertools.double_loop_inner_loopback({0, 3}, {0, 10}) do
        table.insert(blocks, grid.get_tile_position(i, j))
    end

    for j, i in itertools.double_loop_inner_loopback({0, 1}, {4, 12}) do
        table.insert(blocks, grid.get_tile_position(i, j))
    end

    return blocks
end

function map_entities.get_left_side_pressure_blocks(): {Point}
    local blocks: {Point} = {}

    for i, j in itertools.double_loop_inner_loopback({16, 13, -1}, {10, 0, -1}) do
        table.insert(blocks, grid.get_tile_position(i, j))
    end

    for j, i in itertools.double_loop_inner_loopback({10, 9, -1}, {12, 4, -1}) do
        table.insert(blocks, grid.get_tile_position(i, j))
    end

    return blocks
end

function map_entities.get_player_start_positions(number_of_players: integer): {Point}
    local x_min = 0
    local x_max = 16
    local y_min = 0
    local y_max = 10

    local corners = {
        grid.get_tile_position(x_min, y_min),
        grid.get_tile_position(x_max, y_max),
        grid.get_tile_position(x_max, y_min),
        grid.get_tile_position(x_min, y_max),
    }
    local center = {
        grid.get_tile_position(math.floor(x_max / 2), math.floor(y_max / 2))
    }
    local inner_positions = {
        grid.get_tile_position(x_min + 5, y_min + 2),
        grid.get_tile_position(x_max - 5, y_max - 2),
        grid.get_tile_position(x_max - 5, y_min + 2),
        grid.get_tile_position(x_min + 5, y_max - 2),
    }

    local function get_positions(): {Point}
        if number_of_players == 5 then
            -- Only if there are 5 players can you start dead in the middle
            return itertools.combine(corners, center)
        else
            local extra_on_sides = {
                grid.get_tile_position(x_min, math.floor(y_max / 2)),
                grid.get_tile_position(x_max, math.floor(y_max / 2)),
            }
            local result = itertools.combine(corners, inner_positions, extra_on_sides)
            return {table.unpack(result, 1, number_of_players)}
        end
    end

    if settings.game_rules.players.start_position_shuffle then
        return itertools.shuffle(get_positions())
    else
        return get_positions()
    end
end

function map_entities.get_goals(): {Goal}
    return maps.get_layout():get_goals()
end

function map_entities.get_conveyor_belts(): {ConveyorBelt}
    return maps.get_layout():get_conveyor_belts()
end

return map_entities
