package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local grid = require("level_layout.grid")
local pressure_blocks = require("pressure_block")

local STEP = 1 / 60

--- Sudden death from both sides, `seconds` after its first blocks started to fall.
local function sudden_death_for(seconds)
    local blocks = pressure_blocks.new("left_right", true)
    blocks.dropping = true

    function blocks:run(time)
        for _ = 1, math.floor(time / STEP + 0.5) do
            self:update(STEP)
        end
    end

    function blocks:count_down()
        local down = 0
        for _ in pairs(self.on_ground.set) do
            down = down + 1
        end
        return down
    end

    function blocks:is_down_on(column, row)
        for block in pairs(self.on_ground.set) do
            if block.position:equal(grid.get_tile_position(column, row)) then
                return true
            end
        end
        return false
    end

    blocks:run(seconds)
    return blocks
end

describe("a pressure block", function()
    it("is down on the top row 0.17 s after it starts to fall", function()
        assert.are.same(
            {false, true},
            {sudden_death_for(0.15):is_down_on(0, 0), sudden_death_for(0.19):is_down_on(0, 0)}
        )
    end)

    it("is down on the bottom row 0.83 s after it starts to fall", function()
        assert.are.same(
            {false, true},
            {sudden_death_for(0.81):is_down_on(16, 10), sudden_death_for(0.86):is_down_on(16, 10)}
        )
    end)
end)

describe("sudden death", function()
    it("starts a block on each side every 0.63 s", function()
        local blocks = sudden_death_for(38 / 60 * 3 + 0.03)
        assert.are.equal(8, #blocks.in_air + blocks:count_down())
    end)

    it("has the left and right sides closed after 39.4 s", function()
        assert.are.same(
            {123, 124},
            {sudden_death_for(39.35):count_down(), sudden_death_for(39.45):count_down()}
        )
    end)

    it("lets the blocks in the air come down when it is stopped, and starts no more", function()
        local blocks = sudden_death_for(0.75)
        local in_air = #blocks.in_air
        blocks.dropping = false
        blocks:run(3)
        assert.are.same({3, 0, 4}, {in_air, #blocks.in_air, blocks:count_down()})
    end)
end)
