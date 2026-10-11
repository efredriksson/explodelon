package.path = "src/?.lua;" .. package.path
require("tl").loader()

local flames = require("bombs.flames")

--- What each drawn tile does to an arm: '.' open floor, 'O' the centre, '#' hard block,
-- 'S' soft block or bomb, 'I' item. Outside the drawing is a wall.
local MEETING = {["."] = "passes", O = "passes", ["#"] = "capped_before", S = "flat_before", I = "ends_on"}

local OPEN = {
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
}
local OPEN_CENTER = {6, 6}

local BOXED_IN = {
    "###",
    "#.#",
    "###",
}

-- From the centre at column 4: a hard block three tiles left, a soft block
-- three tiles right, an item two tiles down.
local OBSTACLES = {
    ".........",
    ".........",
    ".#..O..S.",
    ".........",
    "....I....",
    ".........",
}
local OBSTACLES_CENTER = {4, 2}

local function meets_on(rows)
    return function(i, j)
        local row = rows[j + 1]
        local tile = row and row:sub(i + 1, i + 1) or ""
        return MEETING[tile] or "capped_before"
    end
end

--- Small enough to look on either side of every change, none of which come
-- closer together than 1/60 s.
local STEP = 1 / 120

local function steps_in(seconds)
    return math.floor(seconds / STEP + 0.5)
end

--- The explosion as it stands `seconds` after it went off.
local function explosion_after(seconds, rows, center, fire)
    local explosion = flames.new(center[1], center[2], fire)
    local meets = meets_on(rows)
    for _ = 1, steps_in(seconds) do
        explosion:advance(STEP, meets)
    end
    return explosion
end

--- What `probe` finds just before and just after `seconds` have passed.
local function around(seconds, probe)
    return {probe(seconds - STEP), probe(seconds + STEP)}
end

local function flame_at(explosion, i, j)
    for _, flame in ipairs(explosion:flames()) do
        if flame.i == i and flame.j == j then
            return flame
        end
    end
    return nil
end

local function reach_right(explosion)
    local reach = 0
    while flame_at(explosion, explosion.i + reach + 1, explosion.j) do
        reach = reach + 1
    end
    return reach
end

describe("flame growth", function()
    local function reach_after(seconds)
        return reach_right(explosion_after(seconds, OPEN, OPEN_CENTER, 6))
    end

    it("shows nothing as the bomb goes off", function()
        assert.are.same({}, explosion_after(0.008, OPEN, OPEN_CENTER, 6):flames())
    end)

    it("lights the centre and the first ring together after 0.017 s", function()
        local explosion = explosion_after(0.025, OPEN, OPEN_CENTER, 6)
        assert.are.equal("center", flame_at(explosion, 6, 6).shape)
        assert.are.equal(1, reach_right(explosion))
    end)

    for ring = 2, 6 do
        local seconds = 1 / 60 + (ring - 1) * 2 / 60
        it(("lights ring %d after %.2f s"):format(ring, seconds), function()
            assert.are.same({ring - 1, ring}, around(seconds, reach_after))
        end)
    end

    it("draws a tip on the outermost tile and middles behind it", function()
        local explosion = explosion_after(0.092, OPEN, OPEN_CENTER, 6)
        assert.are.equal("middle", flame_at(explosion, 8, 6).shape)
        assert.are.equal("tip", flame_at(explosion, 9, 6).shape)
    end)

    it("catches up on every ring after one long step", function()
        local explosion = flames.new(6, 6, 6)
        explosion:advance(0.192, meets_on(OPEN))
        assert.are.equal(6, reach_right(explosion))
    end)
end)

describe("the fade of a fire 6 flame, at full length after 0.183 s", function()
    local function phase_after(seconds)
        return flame_at(explosion_after(seconds, OPEN, OPEN_CENTER, 6), 6, 6).phase
    end

    local function is_over_after(rows, center, fire)
        return function(seconds)
            return explosion_after(seconds, rows, center, fire):is_over()
        end
    end

    it("starts after it has stayed thick for 0.133 s", function()
        assert.are.same({1, 2}, around(0.317, phase_after))
    end)

    it("thins one phase every 0.083 s", function()
        assert.are.same({2, 3}, around(0.4, phase_after))
        assert.are.same({3, 4}, around(0.483, phase_after))
    end)

    it("is over after 0.25 s", function()
        assert.are.same({false, true}, around(0.567, is_over_after(OPEN, OPEN_CENTER, 6)))
    end)

    it("is over 0.133 s sooner for a fire 2 flame", function()
        assert.are.same({false, true}, around(0.433, is_over_after(OPEN, OPEN_CENTER, 2)))
    end)

    it("is over no sooner when every arm is blocked at once", function()
        assert.are.same({false, true}, around(0.567, is_over_after(BOXED_IN, {1, 1}, 6)))
    end)

    it("stops hurting 0.017 s into the thinnest phase", function()
        local function is_deadly_after(seconds)
            return flame_at(explosion_after(seconds, OPEN, OPEN_CENTER, 6), 9, 6).deadly
        end
        assert.are.same({true, false}, around(0.5, is_deadly_after))
    end)
end)

describe("flame arm", function()
    local function arm_tiles(direction)
        local explosion = explosion_after(0.192, OBSTACLES, OBSTACLES_CENTER, 6)
        local shapes = {}
        for _, flame in ipairs(explosion:flames()) do
            if flame.direction == direction then
                table.insert(shapes, flame.shape)
            end
        end
        return shapes
    end

    it("ends in a tip on the tile before a hard block", function()
        assert.are.same({"middle", "tip"}, arm_tiles("left"))
    end)

    it("ends flat on the tile before a soft block", function()
        assert.are.same({"middle", "middle"}, arm_tiles("right"))
    end)

    it("covers an item's tile with a tip and ends there", function()
        assert.are.same({"middle", "tip"}, arm_tiles("down"))
    end)

    it("ends in a tip at the edge", function()
        assert.are.same({"middle", "tip"}, arm_tiles("up"))
    end)

    it("loses its end cap for 0.017 s, 0.033 s after the last ring, when it stopped short", function()
        local function left_end_after(seconds)
            return flame_at(explosion_after(seconds, OBSTACLES, OBSTACLES_CENTER, 6), 2, 2).shape
        end
        assert.are.same({"tip", "middle", "tip"}, {left_end_after(0.208), left_end_after(0.225), left_end_after(0.242)})
    end)

    it("keeps its end cap then at full length", function()
        assert.are.equal("tip", flame_at(explosion_after(0.225, OPEN, OPEN_CENTER, 6), 12, 6).shape)
    end)

    it("stays stopped after what stopped it is gone", function()
        local explosion = explosion_after(0.092, OBSTACLES, OBSTACLES_CENTER, 6)
        explosion:advance(0.1, meets_on(OPEN))
        assert.are.equal(2, reach_right(explosion))
    end)
end)

describe("an explosion made to burn as long as another", function()
    local LATER = 0.067

    --- A fire-6 explosion and, LATER after it, a second one of `fire` told to burn as long as the first. Both as
    -- they stand `seconds` after the first went off.
    local function pair_after(seconds, fire)
        local first, second = flames.new(6, 6, 6), nil
        local meets = meets_on(OPEN)
        for step = 1, steps_in(seconds) do
            first:advance(STEP, meets)
            if second then
                second:advance(STEP, meets)
            end
            if step == steps_in(LATER) then
                second = flames.new(6, 9, fire)
                second:burn_as_long_as(first)
            end
        end
        return first, second
    end

    it("thins in step with it", function()
        for _, seconds in ipairs({0.308, 0.325, 0.408, 0.492}) do
            local first, second = pair_after(seconds, 1)
            assert.are.equal(first:phase(), second:phase())
        end
    end)

    it("goes out at the same moment", function()
        local function is_second_over_after(seconds)
            local _, second = pair_after(seconds, 1)
            return second:is_over()
        end
        assert.are.same({false, true}, around(0.567, is_second_over_after))
    end)

    it("still grows and loses its bomb on its own time", function()
        local _, second = pair_after(LATER + 0.108, 1)
        assert.are.equal(0, second:burst_stage())
    end)

    it("keeps its own fade when it outlasts the other", function()
        local _, second = pair_after(LATER + 0.558, 6)
        assert.is_false(second:is_over())
    end)
end)

describe("growth", function()
    it("takes 0.033 s a tile", function()
        assert.are.equal(4 / 60, flames.growth_time(2))
    end)
end)

describe("bomb burst", function()
    local function stage_after(fire)
        return function(seconds)
            return explosion_after(seconds, OPEN, OPEN_CENTER, fire):burst_stage()
        end
    end

    it("cracks, breaks and scatters on the centre while the flame grows", function()
        assert.are.equal(1, stage_after(6)(0.008))
        assert.are.same({1, 2}, around(0.117, stage_after(6)))
        assert.are.same({2, 3}, around(0.217, stage_after(6)))
    end)

    it("is gone 0.083 s after the last ring", function()
        assert.are.same({3, 0}, around(0.267, stage_after(6)))
        assert.are.same({2, 0}, around(0.133, stage_after(2)))
    end)
end)
