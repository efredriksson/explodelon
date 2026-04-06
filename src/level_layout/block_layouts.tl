local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local entities = require("level_layout.maps.entities")
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

local function place_soft_blocks(
    layout: {integer: {integer: BlockType}}, exclusion_zone: {Point}
)
    local dim = grid.dimensions()
    local count = 0
    while count < settings.game_rules.items.nbr_soft_blocks do
        local i = lutro.math.random(dim.x_max + 1) - 1
        local j = lutro.math.random(dim.y_max + 1) - 1
        local cell: BlockType = layout[i][j]
        if cell == "none"
            and not contains_point(exclusion_zone, grid.get_tile_position(i, j)) then
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

local record QuadrantCell
    distance: integer
    i: integer
    j: integer
end

function QuadrantCell.new(
    i: integer, j: integer, corner_x: integer, corner_y: integer
): QuadrantCell
    local self: QuadrantCell = setmetatable({}, {__index = QuadrantCell})
    self.i = i
    self.j = j
    self.distance = math.abs(i - corner_x) + math.abs(j - corner_y)
    return self
end

function QuadrantCell:can_place_soft_block(
    layout: {integer: {integer: BlockType}}, exclusion_zone: {Point}
): boolean
    return layout[self.i][self.j] == "none"
        and not contains_point(exclusion_zone, grid.get_tile_position(self.i, self.j))
end

local function distance_to_corner(first: QuadrantCell, second: QuadrantCell): boolean
    if first.distance ~= second.distance then
        return first.distance < second.distance
    end
    return first.i < second.i
end

local function quadrant_cells(
    x_min: integer,
    x_max: integer,
    y_min: integer,
    y_max: integer,
    corner_x: integer,
    corner_y: integer
): {QuadrantCell}
    local cells: {QuadrantCell} = {}
    for i = x_min, x_max do
        for j = y_min, y_max do
            table.insert(cells, QuadrantCell.new(i, j, corner_x, corner_y))
        end
    end
    table.sort(cells, distance_to_corner)
    return cells
end

function block_layouts.quadrant(occupies: {Kinematic}): {integer: {integer: BlockType}}
    local layout = new_empty_layout()
    local exclusion_zone = player_exclusion_zone(occupies)
    local dim = grid.dimensions()
    local x_mid = math.floor(dim.x_max / 2)
    local y_mid = math.floor(dim.y_max / 2)
    local total = settings.game_rules.items.nbr_soft_blocks
    local per_quadrant = math.floor(total / 4)
    local remainder = total - per_quadrant * 4

    -- fmt: off
    local top_left     = quadrant_cells(1,         x_mid     - 1,   1,         y_mid     - 1,   1,             1            )
    local top_right    = quadrant_cells(x_mid + 1, dim.x_max - 1,   1,         y_mid     - 1,   dim.x_max - 1, 1            )
    local bottom_left  = quadrant_cells(1,         x_mid     - 1,   y_mid + 1, dim.y_max - 1,   1,             dim.y_max - 1)
    local bottom_right = quadrant_cells(x_mid + 1, dim.x_max - 1,   y_mid + 1, dim.y_max - 1,   dim.x_max - 1, dim.y_max - 1)
    -- fmt: on
    local all_quadrants = {top_left, top_right, bottom_left, bottom_right}

    for quadrant_index, cells in ipairs(all_quadrants) do
        local count = per_quadrant + (quadrant_index <= remainder and 1 or 0)
        local placed = 0
        for _, cell in ipairs(cells) do
            if placed >= count then
                break
            end
            if cell:can_place_soft_block(layout, exclusion_zone) then
                layout[cell.i][cell.j] = "soft"
                placed = placed + 1
            end
        end
    end
    return layout
end

return block_layouts
