package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)
local sound_log = require("spec.support.sound_log")
sound_log.install()

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local bomb_field = require("spec.support.bomb_field")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
local battle_end_scene = require("game.battle_end_scene")
local dinos = require("dinos")
local players = require("players")
local pressure_blocks = require("pressure_block")

local STEP = bomb_field.STEP
-- A row of the factory floor without conveyor belts.
local ROW = 3
local FROM = 2
local played = sound_log.played

bomb_field.on_the_factory_floor()
before_each(sound_log.clear)

--- An open arena with one bomb on (FROM, ROW) whose sounds are heard.
local function new_field()
    local field = bomb_field.new(FROM, ROW)
    field.bombs.silent = false

    function field:kick_right()
        local i, j = grid.tile_indices(self.bomb.position)
        self.bombs:kick_bomb_on(i, j, vectors.from_direction("right"), {}, self.closed)
    end

    function field:throw(tiles)
        self.bombs:throw_existing(self.bomb, grid.get_tile_position(FROM + tiles, ROW))
    end

    return field
end

describe("the sound of a kick", function()
    it("is made once for a bomb that slides off", function()
        local field = new_field()
        field:kick_right()
        field:run(0.5)
        assert.are.equal(1, played("kick"))
    end)

    it("is not made when the tile behind the bomb is closed", function()
        local field = new_field()
        field:close({FROM + 1, ROW})
        field:kick_right()
        assert.are.equal(0, played("kick"))
    end)
end)

describe("the sound of a thrown bomb", function()
    local FLIGHT_OF_3_TILES = 0.2

    it("is the dino's alone when the bomb comes down on an open tile", function()
        local field = new_field()
        field:throw(3)
        field:run(1)
        assert.are.same({1, 0}, {played("dino_throw"), played("bomb_hop")})
    end)

    it("has one hop for each closed tile the bomb comes down on", function()
        local field = new_field()
        field:close({FROM + 3, ROW}, {FROM + 4, ROW})
        field:throw(3)
        field:run(1)
        assert.are.equal(2, played("bomb_hop"))
    end)

    it("has the hop 0.033 s after the bomb comes down", function()
        local field = new_field()
        field:close({FROM + 3, ROW})
        field:throw(3)
        field:run(FLIGHT_OF_3_TILES + 0.017)
        assert.are.equal(0, played("bomb_hop"))
        field:run(0.04)
        assert.are.equal(1, played("bomb_hop"))
    end)
end)

describe("the sound of pressure blocks", function()
    --- Blocks falling from both sides, stepped until the first one is down.
    local function first_blocks_down()
        local blocks = pressure_blocks.new("left_right")
        blocks.sudden_death = true
        while blocks.on_ground:is_empty() do
            blocks:update(STEP)
        end
        return blocks
    end

    it("starts with one sound when the first blocks fall", function()
        first_blocks_down()
        assert.are.equal(1, played("sudden_death"))
    end)

    it("has one landing for a block that comes down", function()
        first_blocks_down()
        assert.are.equal(1, played("pressure_block_land"))
    end)
end)

describe("the sound of a dash", function()
    local function new_rider(level)
        local start = grid.get_tile_position(FROM, ROW)
        local rider = players.new(1, "kotetsu", start)
        rider.dino = dinos.new(start, "down", "green")
        rider.dino.level = level
        rider.state = "mounted"
        return rider
    end

    it("is made once, however often the dash is asked for", function()
        local rider = new_rider(2)
        rider:dash_with_dino()
        rider:dash_with_dino()
        assert.are.equal(1, played("dino_dash_level_2"))
    end)

    it("ends in a crash for a dino of level 1", function()
        local rider = new_rider(1)
        rider:dash_with_dino()
        rider:end_dash()
        assert.are.equal(1, played("dino_dash_crash"))
    end)

    it("is made again when a dino of level 3 turns", function()
        local rider = new_rider(3)
        rider:dash_with_dino()
        rider:set_movement(rider.position, "left")
        assert.are.equal(2, played("dino_dash_level_3"))
    end)
end)

describe("the end of a battle", function()
    local battle = {update = function() end, draw = function() end}
    local unfinished_game = {game_finished = function() return false end}

    --- A won battle, `seconds` after it was decided.
    local function won_since(seconds)
        local scene = battle_end_scene.new_for_winners(battle, {"kotetsu"}, unfinished_game)
        for _ = 1, math.floor(seconds / STEP + 0.5) + 1 do
            scene:update(STEP)
        end
    end

    it("sounds at once", function()
        won_since(0)
        assert.are.same({1, 0}, {played("battle_decided"), played("winner_cheer")})
    end)

    it("has the winner heard 1.92 s later", function()
        won_since(1.9)
        assert.are.equal(0, played("winner_cheer"))
        sound_log.clear()
        won_since(1.94)
        assert.are.equal(1, played("winner_cheer"))
    end)
end)
