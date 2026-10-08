package.path = "src/?.lua;" .. package.path
require("tl").loader()

local grid_walk = require("grid_walk")
local points = require("engine.geometry.points")
local tile_map = require("spec.support.tile_map")

local TILE = tile_map.TILE
local tiles = tile_map.tiles

--- Walk one pixel per frame like a speed 60 player at 60 fps.
local function walk_frames(rows, start, held, frames, last_axis, facing)
    local walk = {
        position = points.new(start[1], start[2]),
        last_axis = last_axis or "horizontal",
        facing = facing or "right",
    }
    for _ = 1, frames do
        walk = grid_walk.walk(walk.position, held, walk.last_axis, walk.facing, 1, tiles(rows), "walk")
    end
    return walk
end

local function ends_at(rows, start, held, frames, expected, last_axis, facing)
    return function()
        local walk = walk_frames(rows, start, held, frames, last_axis, facing)
        assert.are.same(expected, {walk.position.x, walk.position.y})
    end
end

local CROSSING = {
    "#.#",
    "...",
    "#.#",
}

describe("pixels per frame", function()
    it("walks one pixel per frame at speed 60", function()
        local pixels, carry = grid_walk.pixels_this_frame(60, 1 / 60, 0)
        assert.are.same({1, 0}, {pixels, carry})
    end)

    it("carries the fraction so a speed-up item adds a pixel every eighth frame", function()
        local walked, carry = 0, 0
        for _ = 1, 8 do
            local pixels
            pixels, carry = grid_walk.pixels_this_frame(67.5, 1 / 60, carry)
            walked = walked + pixels
        end
        assert.are.equal(9, walked)
    end)
end)

describe("turning a corner", function()
    for _, offset in ipairs({-8, -5, -1, 1, 4, 7}) do
        it(
            ("cuts diagonally from " .. offset .. " px off the lane and keeps full speed"),
            ends_at(CROSSING, {TILE + offset, TILE}, {"up"}, math.abs(offset) + 3, {TILE, TILE - math.abs(offset) - 3})
        )
    end

    it("does not move at all from 8 px past the lane when that tile is closed",
        ends_at(CROSSING, {TILE + 8, TILE}, {"up"}, 10, {TILE + 8, TILE}))

    it("turns the same way going down",
        ends_at(CROSSING, {TILE - 6, TILE}, {"down"}, 10, {TILE, TILE + 10}))
end)

describe("walking straight", function()
    local PILLARS_BELOW = {
        "....",
        "....",
        "#.#.",
    }

    it("re-centres one pixel on the other axis per pixel walked when a block is in the way",
        ends_at(PILLARS_BELOW, {TILE, TILE + 3}, {"right"}, 5, {TILE + 5, TILE}))

    it("stops against a closed tile and faces the held direction", function()
        local walk = walk_frames({"..#"}, {TILE, 0}, {"right"}, 4, "vertical", "down")
        assert.are.same(
            {TILE, 0, "right", true},
            {walk.position.x, walk.position.y, walk.facing, walk.blocked}
        )
    end)
end)

describe("leaving a bomb", function()
    local BOMB_IN_MIDDLE = {".#."}

    it("walks off the closed tile the player stands on",
        ends_at(BOMB_IN_MIDDLE, {TILE, 0}, {"right"}, 9, {TILE + 9, 0}))

    it("can turn back while the bomb tile is still the nearest",
        ends_at(BOMB_IN_MIDDLE, {TILE + 7, 0}, {"left"}, 3, {TILE + 4, 0}))

    it("cannot turn back once past half a tile",
        ends_at(BOMB_IN_MIDDLE, {TILE + 9, 0}, {"left"}, 3, {TILE + 9, 0}))
end)

describe("looking ahead for an opening", function()
    local GAP_BELOW_NEXT_TILE = {
        "#####",
        ".....",
        "##.##",
    }

    it("stays put when centred and the held direction is closed here",
        ends_at(GAP_BELOW_NEXT_TILE, {TILE, TILE}, {"down"}, 5, {TILE, TILE}))

    it("walks on toward an opening under the leading edge and turns into it",
        ends_at(GAP_BELOW_NEXT_TILE, {TILE + 1, TILE}, {"down"}, 30, {2 * TILE, 2 * TILE}))
end)

describe("open ground", function()
    local FIELD = {
        ".......",
        ".......",
        ".......",
        ".......",
        ".......",
    }
    local PILLARED_CORRIDOR = {
        "#.#.#",
        ".....",
        "#.#.#",
    }

    it("walks straight off the lanes when no block is in the way",
        ends_at(FIELD, {3 * TILE, 3 * TILE + 5}, {"right"}, 20, {3 * TILE + 20, 3 * TILE + 5}))

    it("walks diagonally while both held directions are clear",
        ends_at(FIELD, {3 * TILE, 3 * TILE}, {"right", "up"}, 5, {3 * TILE + 5, 3 * TILE - 5}))

    it("keeps moving when off-centre on both axes and holding away from both centres",
        ends_at(FIELD, {3 * TILE + 2, 3 * TILE - 1}, {"right", "up"}, 3, {3 * TILE + 5, 3 * TILE - 4}))

    it("follows the lanes between pillars instead of walking diagonally",
        ends_at(PILLARED_CORRIDOR, {TILE, TILE}, {"right", "up"}, 20, {TILE + 20, TILE}))

    it("cuts into the next gap when holding a diagonal along pillars",
        ends_at(PILLARED_CORRIDOR, {TILE, TILE}, {"right", "up"}, 40, {3 * TILE, 0}))
end)
