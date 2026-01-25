local const = require("const")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local PLAYER_AREA = rectangles.new(24, 32, 272, 176)
local grid = {}

global record GridDimensions
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
		PLAYER_AREA.x + i * const.BLOCK_SIZE,
		PLAYER_AREA.y + j * const.BLOCK_SIZE,
		const.BLOCK_SIZE,
		const.BLOCK_SIZE
	)
end

function grid.get_tile_position(i: number, j: number): Point
	return grid.get_tile(i, j):top_left()
end

--- Get local position for point in block, so {x, y} ∈ [0, BLOCK_SIZE).
function grid.get_local_tile_position(global_position: Point): Point
	local player_area = grid.area() -- FIXME: Local position should be in grid!
	return points.new(
		math.fmod(global_position.x - player_area.x, const.BLOCK_SIZE),
		math.fmod(global_position.y - player_area.y, const.BLOCK_SIZE)
	)
end

function grid.get_random_tile(): Point
	return grid.get_tile_position(lutro.math.random(17) - 1, lutro.math.random(11) - 1)
end

function grid.snap_to_x(x: number): number
	return math.floor((x - PLAYER_AREA.x) / const.BLOCK_SIZE + 0.5) * const.BLOCK_SIZE + PLAYER_AREA.x
end

function grid.snap_to_y(y: number): number
	return math.floor((y - PLAYER_AREA.y) / const.BLOCK_SIZE + 0.5) * const.BLOCK_SIZE + PLAYER_AREA.y
end

function grid.snap_to(pos: Point): Point
	return points.new(grid.snap_to_x(pos.x), grid.snap_to_y(pos.y))
end

return grid
