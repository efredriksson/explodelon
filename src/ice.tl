local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local grid_walk = require("grid_walk")
local itertools = require("itertools")
local settings = require("settings")

local type Axis = grid_walk.Axis
local type Direction = vectors.Direction
local type GridWalk = grid_walk.GridWalk
local type IceRules = settings.IceRules
local type IsOpen = grid_walk.IsOpen
local type Point = points.Point
local type Vector = vectors.Vector

--- A frame of gliding on ice: the walk it made and the momentum it keeps.
local record Glide
    walk: GridWalk
    velocity: Vector
    carry: Vector
end

local ice = {Glide = Glide}

function Glide.new(walk: GridWalk, velocity: Vector, carry: Vector): Glide
    local self: Glide = setmetatable({}, {__index = Glide})
    self.walk = walk
    self.velocity = velocity
    self.carry = carry
    return self
end

function ice.speed_toward(
    speed: number, max_speed: number, dt: number, rules: IceRules
): number
    return math.min(max_speed, speed + max_speed * rules.acceleration_factor * dt)
end

local function velocity_along_axis(
    velocity: number,
    forward: boolean,
    backward: boolean,
    max_speed: number,
    dt: number,
    rules: IceRules
): number
    local friction = max_speed * rules.friction_factor * dt
    if forward then
        return ice.speed_toward(velocity, max_speed, dt, rules)
    elseif backward then
        return -ice.speed_toward(-velocity, max_speed, dt, rules)
    elseif math.abs(velocity) <= friction then
        return 0
    elseif velocity > 0 then
        return velocity - friction
    else
        return velocity + friction
    end
end

--- Each axis speeds up toward what is held on it and coasts to a stop when
-- nothing is, so a glide turns in a curve rather than square.
function ice.velocity(
    velocity: Vector, held: {Direction}, max_speed: number, dt: number, rules: IceRules
): Vector
    return vectors.new(
        velocity_along_axis(
            velocity.x,
            itertools.contains(held, "right"),
            itertools.contains(held, "left"),
            max_speed,
            dt,
            rules
        ),
        velocity_along_axis(
            velocity.y,
            itertools.contains(held, "down"),
            itertools.contains(held, "up"),
            max_speed,
            dt,
            rules
        )
    )
end

local function direction_of(
    component: number, positive: Direction, negative: Direction
): Direction
    if component > 0 then
        return positive
    elseif component < 0 then
        return negative
    end
    return nil
end

--- An axis loses its speed only to a wall it ran into this frame. Speed too slow
-- for a whole pixel has not tried the wall yet: from rest against a block it has
-- to build up before the walk can round the corner. An axis that did not move
-- with the way still open waited while the lane rules moved the other axis.
local function kept_speed(
    speed: number,
    pixels: integer,
    moved: number,
    toward: Direction,
    at: Point,
    is_open: IsOpen
): number
    if
        pixels == 0 or moved * speed > 0 or grid_walk.is_clear_step(at, toward, is_open)
    then
        return speed
    end
    return 0
end

--- Next to a wall the glide also holds what the player presses across it, so
-- the walk's corner turning catches a gap they press toward, as it does when
-- walking. Momentum alone would round the corner back out onto the lane. In
-- open ground momentum alone steers, which keeps the glide's curve.
local function steering_near_walls(
    position: Point, lead: Direction, held: {Direction}, is_open: IsOpen
): {Direction}
    local glide_line = vectors.from_direction(lead)
    local along_wall = not grid_walk.is_clear_step(position, lead, is_open)
    local function steers(direction: Direction): boolean
        return vectors.from_direction(direction):orthogonal(glide_line)
            and (
                along_wall or not grid_walk.is_clear_step(position, direction, is_open)
            )
    end
    return itertools.combine({lead}, itertools.filter(held, steers))
end

--- Glide a frame on the grid walk: the pixels both axes move together walk
-- diagonally, the rest walk along the faster axis.
function ice.glide(
    position: Point,
    velocity: Vector,
    carry: Vector,
    dt: number,
    last_axis: Axis,
    facing: Direction,
    held: {Direction},
    is_open: IsOpen
): Glide
    local horizontal_pixels, horizontal_carry = grid_walk.pixels_this_frame(
        math.abs(velocity.x), dt, carry.x
    )
    local vertical_pixels, vertical_carry = grid_walk.pixels_this_frame(
        math.abs(velocity.y), dt, carry.y
    )
    local horizontal = direction_of(velocity.x, "right", "left")
    local vertical = direction_of(velocity.y, "down", "up")

    -- The walk faces the faster axis, not the way the player taps: facing the tap
    -- could let the walk step toward an opening against the momentum.
    local function lead_direction(): Direction
        if horizontal_pixels == 0 and vertical_pixels == 0 then
            return facing
        elseif horizontal_pixels >= vertical_pixels then
            return horizontal
        end
        return vertical
    end
    local lead = lead_direction()

    local together = grid_walk.walk(
        position,
        {horizontal, vertical},
        last_axis,
        lead,
        math.min(horizontal_pixels, vertical_pixels),
        is_open,
        "walk"
    )
    local function walk_rest(): GridWalk
        if together.blocked then
            return together
        end
        return grid_walk.walk(
            together.position,
            steering_near_walls(together.position, lead, held, is_open),
            together.last_axis,
            lead,
            math.abs(horizontal_pixels - vertical_pixels),
            is_open,
            "walk"
        )
    end
    local walk = walk_rest()
    local moved = position:vector_to(walk.position)
    return Glide.new(
        walk,
        vectors.new(
            kept_speed(
                velocity.x,
                horizontal_pixels,
                moved.x,
                horizontal,
                walk.position,
                is_open
            ),
            kept_speed(
                velocity.y, vertical_pixels, moved.y, vertical, walk.position, is_open
            )
        ),
        vectors.new(horizontal_carry, vertical_carry)
    )
end

return ice
