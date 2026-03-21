local entities = require("level_layout.maps.entities")
local grid = require("level_layout.grid")
local itertools = require("itertools")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local settings = require("settings")

local type BlockType = entities.BlockType
local type Point = points.Point
local type Kinematic = require("kinematic")

local block_layouts = {}

local function contains_point(list: {Point}, p: Point): boolean
    for _, elem in ipairs(list) do
        if elem:equal(p) then
            return true
        end
    end
    return false
end

local function new_empty_layout(): {integer: {integer: BlockType}}
    local dim = grid.dimensions()
    local layout: {integer: {integer: BlockType}} = {}
    for i = 0, dim.x_max do
        layout[i] = {}
        for j = 0, dim.y_max do
            layout[i][j] = "none"
        end
    end
    return layout
end

local function grid_cell_type(i: integer, j: integer): BlockType
    if j == 2 and (i == 1 or i == 6) then
        return "hard_tall"
    else
        return "hard"
    end
end

local function player_exclusion_zone(occupies: {Kinematic}): {Point}
    local close_to_entity: {Point} = {}
    for _, occupied in ipairs(occupies) do
        -- Do allow some positions close to occupied entity to have soft blocks:
        local sum_to_allow = lutro.math.random() < 0.5 and 2 or 0
        for j, i in itertools.double_loop_inner_loopback({-1, 1}, {-1, 1}) do
            if sum_to_allow ~= math.abs(i + j) or (i == 0 and j == 0) then
                local close_by = vectors.new(j, i):scale(grid.TILE_SIZE)
                table.insert(close_to_entity, occupied:get_position():move(close_by))
            end
        end
    end
    return close_to_entity
end

local function place_soft_blocks(layout: {integer: {integer: BlockType}}, exclusion_zone: {Point})
    local dim = grid.dimensions()
    local count = 0
    while count < settings.game_rules.items.nbr_soft_blocks do
        local i = lutro.math.random(dim.x_max + 1) - 1
        local j = lutro.math.random(dim.y_max + 1) - 1
        local cell: BlockType = layout[i][j]
        if cell == "none" and not contains_point(exclusion_zone, grid.get_tile_position(i, j)) then
            layout[i][j] = "soft"
            count = count + 1
        end
    end
end

function block_layouts.grid(occupies: {Kinematic}): {integer: {integer: BlockType}}
    local layout = new_empty_layout()
    for i = 0, 7 do
        for j = 0, 4 do
            layout[1 + i * 2][1 + j * 2] = grid_cell_type(i, j)
        end
    end
    place_soft_blocks(layout, player_exclusion_zone(occupies))
    return layout
end

function block_layouts.empty(occupies: {Kinematic}): {integer: {integer: BlockType}}
    local layout = new_empty_layout()
    place_soft_blocks(layout, player_exclusion_zone(occupies))
    return layout
end

return block_layouts
