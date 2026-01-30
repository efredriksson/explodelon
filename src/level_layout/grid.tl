local logger = require("engine.logger")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local PLAYER_AREA = rectangles.new(24, 32, 272, 176)
local grid = {
	TILE_SIZE = 16,
}

local record GridDimensions
	x_min: integer
	x_max: integer
	y_min: integer
	y_max: integer
end

function grid.area(): Rectangle
	return PLAYER_AREA
end

function grid.dimensions(): GridDimensions
    return {
        x_min = 0,
        x_max = 16,
        y_min = 0,
        y_max = 10
    }
end

function grid.get_tile(i: number, j: number): Rectangle
	return rectangles.new(
		PLAYER_AREA.x + i * grid.TILE_SIZE,
		PLAYER_AREA.y + j * grid.TILE_SIZE,
		grid.TILE_SIZE,
		grid.TILE_SIZE
	)
end

function grid.get_tile_position(i: number, j: number): Point
	return grid.get_tile(i, j):top_left()
end

--- Get local position for point in block, so {x, y} ∈ [0, TILE_SIZE).
function grid.get_local_tile_position(global_position: Point): Point
	local player_area = grid.area()
	return points.new(
		math.fmod(global_position.x - player_area.x, grid.TILE_SIZE),
		math.fmod(global_position.y - player_area.y, grid.TILE_SIZE)
	)
end

function grid.get_random_tile(): Point
    local dim = grid.dimensions()
	return grid.get_tile_position(
        lutro.math.random(dim.x_max + 1) - 1,
        lutro.math.random(dim.y_max + 1) - 1
    )
end

function grid.snap_to_x(x: number): number
	return math.floor((x - PLAYER_AREA.x) / grid.TILE_SIZE + 0.5) * grid.TILE_SIZE + PLAYER_AREA.x
end

function grid.snap_to_y(y: number): number
	return math.floor((y - PLAYER_AREA.y) / grid.TILE_SIZE + 0.5) * grid.TILE_SIZE + PLAYER_AREA.y
end

function grid.snap_to(pos: Point): Point
	return points.new(grid.snap_to_x(pos.x), grid.snap_to_y(pos.y))
end

function grid.outside_on_opposite_side(out_pos: Point): Point
    if out_pos.y < PLAYER_AREA.y then
        -- exiting top
        return points.new(out_pos.x, PLAYER_AREA.y + PLAYER_AREA.height + grid.TILE_SIZE)
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
