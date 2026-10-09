package.path = "src/?.lua;" .. package.path
require("tl").loader()

local ice = require("ice")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local tile_map = require("spec.support.tile_map")

local TILE = tile_map.TILE
local tiles = tile_map.tiles
local FRAME = 1 / 60
local SPEED = 60
local RULES = {acceleration_factor = 4, friction_factor = 1}

local FIELD = {
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
}

local LANE_WITH_PILLARS_BELOW = {
    "..........",
    ".#.#.#.#.#",
    "..........",
}

local WALL_WITH_GAP_BELOW = {
    "........",
    "###.####",
    "###.####",
}

local BLOCK_ABOVE_LEFT = {
    ".#....",
    "......",
}

--- Glide `frames` frames from `start` with `velocity`; `held(frame)` gives what
-- the player holds, or nothing at all to glide on without ever changing speed.
local function glide(rows, start, velocity, frames, held)
    local state = {
        walk = {position = points.new(start[1], start[2]), last_axis = "horizontal", facing = "right"},
        velocity = vectors.new(velocity[1], velocity[2]),
        carry = vectors.new(0, 0),
    }
    for frame = 1, frames do
        local next_velocity = state.velocity
        local pressed = {}
        if held then
            pressed = held(frame)
            next_velocity = ice.velocity(state.velocity, pressed, SPEED, FRAME, RULES)
        end
        state = ice.glide(
            state.walk.position,
            next_velocity,
            state.carry,
            FRAME,
            state.walk.last_axis,
            state.walk.facing,
            pressed,
            tiles(rows)
        )
    end
    return state
end

local function ends_at(rows, start, velocity, frames, expected, held)
    return function()
        local state = glide(rows, start, velocity, frames, held)
        assert.are.same(expected, {
            state.walk.position.x,
            state.walk.position.y,
            state.velocity.x,
            state.velocity.y,
        })
    end
end

local function holding(...)
    local directions = {...}
    return function()
        return directions
    end
end

describe("ice speed", function()
    it("reaches full speed after a quarter second of holding", function()
        local velocity = vectors.new(0, 0)
        for _ = 1, 15 do
            velocity = ice.velocity(velocity, {"right"}, SPEED, FRAME, RULES)
        end
        assert.are.same({SPEED, 0}, {velocity.x, velocity.y})
    end)

    it("coasts to a stop a second after letting go",
        ends_at(FIELD, {0, 0}, {SPEED, 0}, 60, {29, 0, 0, 0}, holding()))
end)

describe("gliding", function()
    it("moves each axis at its own speed over open ground",
        ends_at(FIELD, {0, 0}, {60, 30}, 60, {60, 30, 60, 30}))

    it("stops at a wall and loses the speed into it",
        ends_at({"...."}, {0, 0}, {120, 0}, 60, {3 * TILE, 0, 0, 0}))

    it("slides along a wall it hits at an angle, losing only the speed into it",
        ends_at({"........"}, {0, 0}, {60, 60}, 30, {30, 0, 60, 0}))

    it("turns into a gap in a wall it presses against, as walking does", function()
        local state = glide(WALL_WITH_GAP_BELOW, {0, 0}, {SPEED, 0}, 60, holding("right", "down"))
        assert.are.same({3 * TILE, 20}, {state.walk.position.x, state.walk.position.y})
    end)

    it("builds up speed from rest against a block and rounds its corner", function()
        local state = glide(BLOCK_ABOVE_LEFT, {24, 16}, {0, 0}, 24, holding("up"))
        assert.are.same({2 * TILE, 0}, {state.walk.position.x, state.walk.position.y})
    end)

    it("rounds a pillar corner onto the lane, as walking does",
        ends_at(LANE_WITH_PILLARS_BELOW, {0, 3}, {60, 0}, 30, {30, 0, 60, 0}))
end)
