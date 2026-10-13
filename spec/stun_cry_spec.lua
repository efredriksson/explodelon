package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)
local sound_log = require("spec.support.sound_log")
sound_log.install()

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local bomb_field = require("spec.support.bomb_field")
local collision = require("engine.collision")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
local dino_roars = require("dino_roars")
local dinos = require("dinos")
local itertools = require("itertools")
local players = require("players")

local STEP = bomb_field.STEP
-- A row of the factory floor without conveyor belts.
local ROW = 3
local FROM = 2
local WIND_UP_STEPS = 34
local STEPS_PER_TILE = 4
local HOLD_STEPS = 40
local STUN_STEPS = 30
-- A timer that ends on a step boundary may run one step long.
local SLACK = 2

bomb_field.on_the_factory_floor()
before_each(sound_log.clear)

local function new_rider(level)
    local start = grid.get_tile_position(FROM, ROW)
    local rider = players.new(1, "kotetsu", start)
    rider.dino = dinos.new(start, "right", "yellow")
    rider.dino.level = level
    rider.state = "mounted"
    rider.direction = "right"
    return rider
end

--- A player `tiles` ahead of the rider, `off_row` pixels below the rider's row.
local function new_victim(tiles, off_row)
    local position = grid.get_tile_position(FROM + tiles, ROW):move(vectors.new(0, off_row or 0))
    return players.new(2, "kotetsu", position)
end

--- Lets the rider cry at `victims` for `steps` steps. Returns the step on which each victim was first
-- stunned (nil if never), in the order of `victims`.
local function cry_at(rider, victims, steps)
    local everyone = itertools.combine({rider}, victims)
    local alive = collision.new_group(everyone)
    local roars = dino_roars.new(alive, collision.new_group(), collision.new_group())
    local first_stunned = {}
    rider:stun_cry_with_dino()
    for step = 1, steps do
        for _, player in ipairs(everyone) do
            player:update(STEP)
        end
        roars:resolve(collision.new_lookup(alive.set), rider)
        for index, victim in ipairs(victims) do
            if victim:is_stunned() and not first_stunned[index] then
                first_stunned[index] = step
            end
        end
    end
    return first_stunned
end

local function longest_reach(level)
    return level * 3
end

local function whole_cry(level)
    return WIND_UP_STEPS + longest_reach(level) * STEPS_PER_TILE + HOLD_STEPS + SLACK
end

--- `reached` and `missed` are victims as {tiles ahead, pixels off the row}. The rider stands
-- `rider_off_tile` pixels to the right of its tile.
local function stuns_one_but_not_the_other(level, reached, missed, rider_off_tile)
    return function()
        local rider = new_rider(level)
        rider.position = rider.position:move(vectors.new(rider_off_tile or 0, 0))
        local victims = {new_victim(reached[1], reached[2]), new_victim(missed[1], missed[2])}
        local stunned = cry_at(rider, victims, whole_cry(level))
        assert.is_truthy(stunned[1])
        assert.is_nil(stunned[2])
    end
end

local function reaches_tile_on_time(tiles)
    return function()
        local stunned_on = cry_at(new_rider(3), {new_victim(tiles)}, whole_cry(3))[1]
        local on_time = WIND_UP_STEPS + tiles * STEPS_PER_TILE
        assert.is_true(stunned_on >= on_time and stunned_on <= on_time + SLACK)
    end
end

describe("how far a stun cry reaches", function()
    for level = 1, 3 do
        local reach = longest_reach(level)
        it("is " .. reach .. " tiles for a dino of level " .. level, stuns_one_but_not_the_other(level, {reach}, {reach + 1}))
    end

    it("is one tile soon after the cry comes out", reaches_tile_on_time(1))
    it("grows by a tile at a steady pace", reaches_tile_on_time(7))
    it("covers the tiles its victims are nearest to", stuns_one_but_not_the_other(1, {2, 7}, {2, 9}))
    it("starts from the tile the rider is nearest to", stuns_one_but_not_the_other(1, {3}, {4}, -7))
end)

describe("how long a stun cry lasts", function()
    for level = 1, 3 do
        it("is the time it takes to reach its last tile and two thirds of a second more, for a dino of level " .. level, function()
            local crying, done = new_rider(level), new_rider(level)
            cry_at(crying, {}, whole_cry(level) - 2 * SLACK)
            cry_at(done, {}, whole_cry(level))
            assert.is_true(crying:is_roaring())
            assert.is_false(done:is_roaring())
        end)
    end
end)

describe("a player stunned by a stun cry", function()
    it("stays stunned for as long as the cry reaches them", function()
        local victim = new_victim(1)
        cry_at(new_rider(3), {victim}, whole_cry(3))
        assert.is_true(victim:is_stunned())
    end)

    it("comes round half a second after the cry has ended", function()
        local early, late = new_victim(1), new_victim(1)
        cry_at(new_rider(3), {early}, whole_cry(3) + STUN_STEPS - 2 * SLACK)
        cry_at(new_rider(3), {late}, whole_cry(3) + STUN_STEPS + SLACK)
        assert.is_true(early:is_stunned())
        assert.is_false(late:is_stunned())
    end)

    it("is heard being stunned once, however long the cry holds them", function()
        cry_at(new_rider(3), {new_victim(1)}, whole_cry(3))
        assert.are.equal(1, sound_log.played("player_stun"))
    end)
end)
