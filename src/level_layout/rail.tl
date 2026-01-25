local grid = require("level_layout.grid")
local vectors = require("engine.geometry.vectors")


local PLAYER_AREA = grid.area()
local RAIL_LENGHT = PLAYER_AREA.width * 2 + PLAYER_AREA.height * 2
local DISTANCE_TO_SIDE: {Direction: number} = {
    up = 0,
    right = PLAYER_AREA.width,
    down = PLAYER_AREA.width + PLAYER_AREA.height,
    left = PLAYER_AREA.width * 2 + PLAYER_AREA.height,
}
local START_POSITION_OF_SIDE: {Direction: Point} = {
    up = PLAYER_AREA:top_left(),
    right = PLAYER_AREA:top_left():move(
        vectors.new(PLAYER_AREA.width, 0)
    ),
    down = PLAYER_AREA:top_left():move(
        vectors.new(PLAYER_AREA.width, PLAYER_AREA.height)
    ),
    left = PLAYER_AREA:top_left():move(
        vectors.new(0, PLAYER_AREA.height)
    ),
}
local MOVE_DIRECTION_OF_SIDE: {Direction: Vector} = {
    up = vectors.new(1, 0),
    right = vectors.new(0, 1),
    down = vectors.new(-1, 0),
    left = vectors.new(0, -1),
}

local rail = {}

function rail.get_side(position: number): Direction
    if position < PLAYER_AREA.width then
        return "up"
    elseif position < PLAYER_AREA.width + PLAYER_AREA.height then
        return "right"
    elseif position < PLAYER_AREA.width * 2 + PLAYER_AREA.height then
        return "down"
    else
        return "left"
    end
end

function rail.get_x_y_position(position: number): Point
    local side = rail.get_side(position)
    local side_move_len = position - DISTANCE_TO_SIDE[side]
    local side_start = START_POSITION_OF_SIDE[side]
    local move_dir = MOVE_DIRECTION_OF_SIDE[side]
    return side_start:move(move_dir:scale(side_move_len))
end

function rail.move_along(current_position: number, move_by: number): number
    local new_position = current_position + move_by
    return new_position % RAIL_LENGHT
end

return rail
