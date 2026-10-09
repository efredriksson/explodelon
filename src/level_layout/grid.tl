local animations = require("engine.animations")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local logger = require("engine.logger")

local type Animation = animations.Animation
local type Direction = vectors.Direction
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local record GridDimensions
    x_min: integer
    x_max: integer
    y_min: integer
    y_max: integer
end

local PLAYER_AREA = rectangles.new(24, 32, 272, 176)
local DIMENSIONS: GridDimensions = {x_min = 0, x_max = 16, y_min = 0, y_max = 10}
local grid = {
    TILE_SIZE = 16,
}

function grid.area(): Rectangle
    return PLAYER_AREA
end

function grid.dimensions(): GridDimensions
    return DIMENSIONS
end

function grid.get_tile(i: integer, j: integer): Rectangle
    return rectangles.new(
        PLAYER_AREA.x + i * grid.TILE_SIZE,
        PLAYER_AREA.y + j * grid.TILE_SIZE,
        grid.TILE_SIZE,
        grid.TILE_SIZE
    )
end

function grid.get_tile_position(i: integer, j: integer): Point
    return grid.get_tile(i, j):top_left()
end

--- Where a sprite taller and wider than its tile is drawn to stand in it.
function grid.block_sprite_position(animation: Animation, block: Point): Point
    -- y: +1 is because of the sprite, look over when doing animations
    return points.new(
        block.x + (grid.TILE_SIZE - animation.width) / 2,
        block.y - animation.height + grid.TILE_SIZE + 1
    )
end

--- Position measured from the top-left corner of the play area.
function grid.position_in_area(position: Point): Point
    return points.new(position.x - PLAYER_AREA.x, position.y - PLAYER_AREA.y)
end

function grid.position_from_area(position_in_area: Point): Point
    return points.new(
        position_in_area.x + PLAYER_AREA.x, position_in_area.y + PLAYER_AREA.y
    )
end

local function nearest_column(x: number): integer
    return math.floor((x - PLAYER_AREA.x) / grid.TILE_SIZE + 0.5)
end

local function nearest_row(y: number): integer
    return math.floor((y - PLAYER_AREA.y) / grid.TILE_SIZE + 0.5)
end

--- Column and row of the tile nearest to a position.
function grid.tile_indices(position: Point): integer, integer
    return nearest_column(position.x), nearest_row(position.y)
end

function grid.get_random_tile(): Point
    local dim = grid.dimensions()
    return grid.get_tile_position(
        lutro.math.random(dim.x_max + 1) - 1, lutro.math.random(dim.y_max + 1) - 1
    )
end

function grid.snap_to_x(x: number): number
    return nearest_column(x) * grid.TILE_SIZE + PLAYER_AREA.x
end

function grid.snap_to_y(y: number): number
    return nearest_row(y) * grid.TILE_SIZE + PLAYER_AREA.y
end

function grid.snap_to(pos: Point): Point
    return points.new(grid.snap_to_x(pos.x), grid.snap_to_y(pos.y))
end

function grid.tile_ahead_of(pos: Point, direction: Direction): Point
    return grid.snap_to(pos):move(
        vectors.from_direction(direction):scale(grid.TILE_SIZE)
    )
end

function grid.outside_on_opposite_side(out_pos: Point): Point
    if out_pos.y < PLAYER_AREA.y then
        -- exiting top
        return points.new(
            out_pos.x, PLAYER_AREA.y + PLAYER_AREA.height + grid.TILE_SIZE
        )
    elseif out_pos.y > PLAYER_AREA.y + PLAYER_AREA.height then
        -- exiting bottom
        return points.new(out_pos.x, PLAYER_AREA.y - grid.TILE_SIZE * 2)
    elseif out_pos.x < PLAYER_AREA.x then
        -- exiting left
        return points.new(PLAYER_AREA.x + PLAYER_AREA.width + grid.TILE_SIZE, out_pos.y)
    elseif out_pos.x > PLAYER_AREA.x + PLAYER_AREA.width then
        -- exiting right
        return points.new(PLAYER_AREA.x - grid.TILE_SIZE * 2, out_pos.y)
    else
        logger.warning("Position is not outside of grid area!")
        return out_pos
    end
end

function grid.outside_visible_area(box: Rectangle): boolean
    return not PLAYER_AREA:expand(grid.TILE_SIZE):contains(box)
end

return grid
