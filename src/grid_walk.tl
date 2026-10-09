local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local itertools = require("itertools")
local grid = require("level_layout.grid")

local type Direction = vectors.Direction
local type Point = points.Point
local type Vector = vectors.Vector

local type Axis = enum
    "horizontal"
    "vertical"
end

--- A dash keeps to the tile lanes even on open ground: it turns square and
-- snaps onto the lane it turns into, where walking would go diagonally or stay
-- off the lane.
local type Gait = enum
    "walk"
    "dash"
end

--- Whether the tile at column i, row j can be walked into.
local type IsOpen = function(i: integer, j: integer): boolean

local HALF_TILE = grid.TILE_SIZE / 2

--- Of several held directions, the one that comes first here is walked.
local PRIORITY: {Direction} = {"right", "down", "left", "up"}

local AXIS_OF: {Direction: Axis} = {
    right = "horizontal",
    left = "horizontal",
    down = "vertical",
    up = "vertical",
}

--- Offset from the position to the player's leading edge. The tile under it is
-- where a player looks for an opening to walk on towards.
local LEADING_EDGE: {Direction: Vector} = {
    right = vectors.new(HALF_TILE - 1, 0),
    down = vectors.new(0, HALF_TILE - 1),
    left = vectors.new(-HALF_TILE, 0),
    up = vectors.new(0, -HALF_TILE),
}

local record Tile
    i: integer
    j: integer
end

local record Step
    moves: {Direction}
    facing: Direction
end

local record GridWalk
    position: Point
    facing: Direction
    last_axis: Axis
    blocked: boolean
end

local grid_walk = {GridWalk = GridWalk, Axis = Axis, Gait = Gait, IsOpen = IsOpen}

local function intersection(first: {Direction}, second: {Direction}): {Direction}
    local function in_both(direction: Direction): boolean
        return itertools.contains(first, direction)
            and itertools.contains(second, direction)
    end
    return itertools.filter(PRIORITY, in_both)
end

local function union(first: {Direction}, second: {Direction}): {Direction}
    local function in_either(direction: Direction): boolean
        return itertools.contains(first, direction)
            or itertools.contains(second, direction)
    end
    return itertools.filter(PRIORITY, in_either)
end

local function on_axis(directions: {Direction}, axis: Axis): {Direction}
    local function along(direction: Direction): boolean
        return AXIS_OF[direction] == axis and itertools.contains(directions, direction)
    end
    return itertools.filter(PRIORITY, along)
end

local function across_axis(directions: {Direction}, axis: Axis): {Direction}
    local function across(direction: Direction): boolean
        return AXIS_OF[direction] ~= axis and itertools.contains(directions, direction)
    end
    return itertools.filter(PRIORITY, across)
end

local function reversed(directions: {Direction}): {Direction}
    local function reverse_held(direction: Direction): boolean
        return itertools.contains(directions, vectors.opposite(direction))
    end
    return itertools.filter(PRIORITY, reverse_held)
end

local function without(directions: {Direction}, removed: {Direction}): {Direction}
    local function kept(direction: Direction): boolean
        return itertools.contains(directions, direction)
            and not itertools.contains(removed, direction)
    end
    return itertools.filter(PRIORITY, kept)
end

local function in_priority_order(directions: {Direction}): {Direction}
    return intersection(PRIORITY, directions)
end

function Tile.new(i: integer, j: integer): Tile
    local self: Tile = setmetatable({}, {__index = Tile})
    self.i = i
    self.j = j
    return self
end

--- The tile whose centre is closest; exactly half way rounds right/down.
function Tile.nearest(position: Point): Tile
    return Tile.new(
        math.floor((position.x + HALF_TILE) / grid.TILE_SIZE),
        math.floor((position.y + HALF_TILE) / grid.TILE_SIZE)
    )
end

function Tile:neighbour(direction: Direction): Tile
    local offset = vectors.from_direction(direction)
    return Tile.new(self.i + math.floor(offset.x), self.j + math.floor(offset.y))
end

function Tile:open_neighbours(is_open: IsOpen): {Direction}
    local function leads_to_open_tile(direction: Direction): boolean
        local neighbour = self:neighbour(direction)
        return is_open(neighbour.i, neighbour.j)
    end
    return itertools.filter(PRIORITY, leads_to_open_tile)
end

function Step.new(moves: {Direction}, facing: Direction): Step
    local self: Step = setmetatable({}, {__index = Step})
    self.moves = moves
    self.facing = facing
    return self
end

function Step:moved(position: Point): Point
    local moved = position
    for _, direction in ipairs(self.moves) do
        moved = moved:move(vectors.from_direction(direction))
    end
    return moved
end

function Step:last_axis(): Axis
    return AXIS_OF[self.moves[#self.moves]]
end

function GridWalk.new(
    position: Point, facing: Direction, last_axis: Axis, blocked: boolean
): GridWalk
    local self: GridWalk = setmetatable({}, {__index = GridWalk})
    self.position = position
    self.facing = facing
    self.last_axis = last_axis
    self.blocked = blocked
    return self
end

local function snap_on_axis(
    offset: number, toward_start: Direction, toward_end: Direction
): {Direction}
    if offset == 0 then
        return {}
    elseif offset < HALF_TILE then
        return {toward_start}
    else
        return {toward_end}
    end
end

--- Directions that bring a misaligned player back to the centre of its nearest tile.
local function snap_toward_centre(position: Point): {Direction}
    return union(
        snap_on_axis(position.x % grid.TILE_SIZE, "left", "right"),
        snap_on_axis(position.y % grid.TILE_SIZE, "up", "down")
    )
end

--- Where a player can step without help from snapping: while off-centre on an axis
-- the player can only go along it, either back to the centre or into the next tile.
local function open_in_place(position: Point, is_open: IsOpen): {Direction}
    local snap = snap_toward_centre(position)
    local neighbours = Tile.nearest(position):open_neighbours(is_open)
    local function crosses_misaligned_axis(direction: Direction): boolean
        return #across_axis(snap, AXIS_OF[direction]) > 0
    end
    local blocked_crossings = itertools.filter(PRIORITY, crosses_misaligned_axis)
    return union(without(neighbours, blocked_crossings), snap)
end

--- Whether a player's box at `position` overlaps the tile in column i, row j.
-- The clearance check works on a column and row instead of a Tile because it
-- runs for every pixel every player walks, where a record per tile adds up.
local function covers_tile(position: Point, i: integer, j: integer): boolean
    return math.abs(i * grid.TILE_SIZE - position.x) < grid.TILE_SIZE
        and math.abs(j * grid.TILE_SIZE - position.y) < grid.TILE_SIZE
end

local function distance_to_tile(position: Point, i: integer, j: integer): number
    return math.abs(i * grid.TILE_SIZE - position.x) + math.abs(
        j * grid.TILE_SIZE - position.y
    )
end

local function blocks_move(
    from: Point, to: Point, is_open: IsOpen, i: integer, j: integer
): boolean
    if is_open(i, j) then
        return false
    end
    return not covers_tile(from, i, j)
        or distance_to_tile(to, i, j) < distance_to_tile(from, i, j)
end

--- Explodelon's rectangle rule: a move is clear unless the player's box enters a
-- closed tile, or goes further into one it already overlaps, such as a bomb
-- that was just placed under the player.
local function is_clear_move(from: Point, to: Point, is_open: IsOpen): boolean
    local left = math.floor(to.x / grid.TILE_SIZE)
    local right = math.floor((to.x + grid.TILE_SIZE - 1) / grid.TILE_SIZE)
    local top = math.floor(to.y / grid.TILE_SIZE)
    local bottom = math.floor((to.y + grid.TILE_SIZE - 1) / grid.TILE_SIZE)
    for i = left, right do
        for j = top, bottom do
            if blocks_move(from, to, is_open, i, j) then
                return false
            end
        end
    end
    return true
end

function grid_walk.is_clear_step(
    position: Point, direction: Direction, is_open: IsOpen
): boolean
    return is_clear_move(
        position, position:move(vectors.from_direction(direction)), is_open
    )
end

--- Explodelon walks diagonally over open ground. The lane rules below are made
-- for an arena with a pillar on every other tile; on open ground they lock
-- players to lanes or, off-centre on both axes, freeze them.
local function step_diagonally_in_open(
    position: Point, held: {Direction}, facing: Direction, is_open: IsOpen
): Step
    if #held < 2 then
        return nil
    end
    local horizontal = on_axis(held, "horizontal")[1]
    local vertical = on_axis(held, "vertical")[1]
    if horizontal == nil or vertical == nil then
        return nil
    end
    local across = position:move(vectors.from_direction(horizontal)):move(
        vectors.from_direction(vertical)
    )
    local clear = grid_walk.is_clear_step(position, horizontal, is_open)
        and grid_walk.is_clear_step(position, vertical, is_open)
        and is_clear_move(position, across, is_open)
    if not clear then
        return nil
    end
    local function keep_facing(): Direction
        if itertools.contains(held, facing) then
            return facing
        end
        return horizontal
    end
    return Step.new({horizontal, vertical}, keep_facing())
end

--- Holding one way across open ground goes straight. The lane rules would pull
-- the player onto the nearest tile's lane even with no block around; here they
-- only step in once the box would run into a block.
local function step_straight_in_open(
    position: Point, held: {Direction}, is_open: IsOpen
): Step
    local direction = held[1]
    if direction == nil or #across_axis(held, AXIS_OF[direction]) > 0 then
        return nil
    end
    if not grid_walk.is_clear_step(position, direction, is_open) then
        return nil
    end
    return Step.new({direction}, direction)
end

local function step_in_open(
    position: Point, held: {Direction}, facing: Direction, is_open: IsOpen, gait: Gait
): Step
    if gait == "dash" then
        return nil
    end
    return step_diagonally_in_open(position, held, facing, is_open)
        or step_straight_in_open(position, held, is_open)
end

--- Last resort before stopping: any held direction the box fits in, so a player
-- off-centre on both axes and holding away from both centres still moves.
local function step_where_box_fits(
    position: Point, held: {Direction}, is_open: IsOpen
): Step
    local function fits(direction: Direction): boolean
        return grid_walk.is_clear_step(position, direction, is_open)
    end
    local possible = itertools.filter(held, fits)
    if #possible == 0 then
        return nil
    end
    return Step.new({possible[1]}, possible[1])
end

--- One pixel in a wanted direction plus one pixel of snap, which is what makes
-- corners round off diagonally and re-centres a player walking straight.
local function move_with_snap(wanted: {Direction}, snap: {Direction}): Step
    if #wanted == 0 or #snap == 0 then
        return nil
    end
    return Step.new({wanted[1], snap[1]}, wanted[1])
end

local function step_in_place(held: {Direction}, in_place: {Direction}): Step
    local possible = intersection(held, in_place)
    if #possible == 0 then
        return nil
    end
    return Step.new({possible[1]}, possible[1])
end

--- Keep walking the way the player faces while what they hold opens up in the
-- tile under their leading edge, e.g. holding down along a wall with a gap ahead.
local function step_toward_opening_ahead(
    position: Point,
    held: {Direction},
    facing: Direction,
    in_place: {Direction},
    is_open: IsOpen
): Step
    if not itertools.contains(in_place, facing) then
        return nil
    end
    local ahead = Tile.nearest(position:move(LEADING_EDGE[facing]))
    local reachable = union({facing}, ahead:open_neighbours(is_open))
    if #intersection(held, reachable) == 0 then
        return nil
    end
    return Step.new({facing}, facing)
end

local function step_by_lane_rules(
    position: Point,
    held: {Direction},
    last_axis: Axis,
    facing: Direction,
    is_open: IsOpen
): Step
    local snap_allowed = without(snap_toward_centre(position), reversed(held))
    local wanted = intersection(held, Tile.nearest(position):open_neighbours(is_open))
    local in_place = open_in_place(position, is_open)
    return move_with_snap(
        across_axis(wanted, last_axis), on_axis(snap_allowed, last_axis)
    ) or move_with_snap(
        on_axis(wanted, last_axis), across_axis(snap_allowed, last_axis)
    ) or step_in_place(held, in_place)
        or step_toward_opening_ahead(position, held, facing, in_place, is_open)
        or step_where_box_fits(position, held, is_open)
end

local function next_step(
    position: Point,
    held: {Direction},
    last_axis: Axis,
    facing: Direction,
    is_open: IsOpen,
    gait: Gait
): Step
    return step_in_open(position, held, facing, is_open, gait)
        or step_by_lane_rules(position, held, last_axis, facing, is_open)
end

--- Whole pixels to walk this frame and the fraction carried over to the next,
-- so a speed of 67.5 px/s at 60 fps walks one extra pixel every eighth frame.
function grid_walk.pixels_this_frame(
    speed: number, dt: number, carry: number
): integer, number
    local budget = carry + speed * dt
    local pixels = math.floor(budget)
    return pixels, budget - pixels
end

--- Walk a player `pixels` one-pixel steps along the tile lanes.
-- `position` is in whole pixels relative to the play area, so a player standing
-- exactly on a tile has both coordinates divisible by the tile size.
function grid_walk.walk(
    position: Point,
    held: {Direction},
    last_axis: Axis,
    facing: Direction,
    pixels: integer,
    is_open: IsOpen,
    gait: Gait
): GridWalk
    if #held == 0 then
        return GridWalk.new(position, facing, last_axis, false)
    end
    local ordered_held = in_priority_order(held)
    local current = GridWalk.new(position, facing, last_axis, false)
    for _ = 1, pixels do
        local step = next_step(
            current.position,
            ordered_held,
            current.last_axis,
            current.facing,
            is_open,
            gait
        )
        if step == nil then
            return GridWalk.new(
                current.position, ordered_held[1], current.last_axis, true
            )
        end
        current = GridWalk.new(
            step:moved(current.position), step.facing, step:last_axis(), false
        )
    end
    return current
end

return grid_walk
