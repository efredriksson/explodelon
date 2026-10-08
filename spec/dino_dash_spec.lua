package.path = "src/?.lua;" .. package.path
require("tl").loader()

local dino_dash = require("dino_dash")
local grid_walk = require("grid_walk")
local points = require("engine.geometry.points")
local tile_map = require("spec.support.tile_map")

local TILE = tile_map.TILE
local tiles = tile_map.tiles
-- Every dash speed is a whole number of pixels at this step, which keeps the positions below exact.
local STEP = 1 / 60

--- Dash `frames` steps to the right; `steer(frame)` gives what the rider holds.
local function dash(rows, start, level, frames, steer)
    local walk = {
        position = points.new(start[1], start[2]),
        last_axis = "horizontal",
        facing = "right",
        blocked = false,
    }
    local carry = 0
    for frame = 1, frames do
        local pixels
        pixels, carry = grid_walk.pixels_this_frame(dino_dash.speed(level), STEP, carry)
        local held = dino_dash.directions(walk.facing, level, steer and steer(frame) or {}, false)
        walk = grid_walk.walk(walk.position, held, walk.last_axis, walk.facing, pixels, tiles(rows), "dash")
        if walk.blocked then
            break
        end
    end
    return walk
end

local function ends_at(rows, start, level, frames, expected, steer)
    return function()
        local walk = dash(rows, start, level, frames, steer)
        assert.are.same(expected, {walk.position.x, walk.position.y, walk.facing})
    end
end

local function holding(direction, from_frame)
    return function(frame)
        if frame >= (from_frame or 1) then
            return {direction}
        end
        return {}
    end
end

--- Pixels a whole brake slides when the game steps `step` seconds at a time.
local function brake_distance(level, step)
    local walked, carry, braked_for = 0, 0, 0
    while braked_for < dino_dash.BRAKE_TIME do
        local pixels
        pixels, carry = grid_walk.pixels_this_frame(dino_dash.brake_speed_over(level, braked_for, step), step, carry)
        walked = walked + pixels
        braked_for = braked_for + step
    end
    return walked
end

local LONG_ROW = {"................................"}

local LANE_WITH_PILLARS_BELOW = {
    "..........",
    ".#.#.#.#.#",
    "..........",
}

local FIELD = {
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
}

describe("dash speed", function()
    for level, speed in ipairs({120, 180, 240}) do
        it(("covers " .. speed .. " px a second at level " .. level),
            ends_at(LONG_ROW, {0, 0}, level, 10, {speed * 10 * STEP, 0, "right"}))
    end
end)

describe("braking", function()
    for name, step in pairs({["1/50 s"] = 1 / 50, ["1/60 s"] = 1 / 60, ["1/144 s"] = 1 / 144}) do
        it("slides a level 2 dino 2 tiles, stepping " .. name, function()
            assert.are.equal(2 * TILE, brake_distance(2, step))
        end)

        it("slides a level 3 dino 3 tiles, stepping " .. name, function()
            assert.are.equal(3 * TILE, brake_distance(3, step))
        end)
    end

    it("is not possible below level 2", function()
        assert.is_false(dino_dash.can_brake(1))
    end)

    it("starts when the rider holds against the dash", function()
        assert.is_true(dino_dash.is_reversing("right", {"down", "left"}))
    end)
end)

describe("what a dashing rider holds", function()
    it("is only the dash direction below level 3",
        function() assert.are.same({"right"}, dino_dash.directions("right", 2, {"down"}, false)) end)

    it("adds the steering direction at level 3",
        function() assert.are.same({"right", "down"}, dino_dash.directions("right", 3, {"down"}, false)) end)

    it("leaves out holding against the dash",
        function() assert.are.same({"right"}, dino_dash.directions("right", 3, {"left"}, false)) end)

    it("does not steer while braking",
        function() assert.are.same({"right"}, dino_dash.directions("right", 3, {"down"}, true)) end)
end)

describe("steering a level 3 dash", function()
    it("turns into the first opening it can snap forward into",
        ends_at(LANE_WITH_PILLARS_BELOW, {1, 0}, 3, 10, {2 * TILE, 17, "down"}, holding("down")))

    it("does not steer below level 3",
        ends_at(LANE_WITH_PILLARS_BELOW, {1, 0}, 2, 10, {31, 0, "right"}, holding("down")))

    it("turns square on open ground onto the nearest column ahead",
        ends_at(FIELD, {1, 2 * TILE}, 3, 12, {3 * TILE, 2 * TILE - 9, "up"}, holding("up", 10)))
end)

describe("dashing into a wall", function()
    it("stops on the last tile and reports it", function()
        local walk = dash({"...."}, {0, 0}, 1, 40)
        assert.are.same({3 * TILE, 0, true}, {walk.position.x, walk.position.y, walk.blocked})
    end)
end)
