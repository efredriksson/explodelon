package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local bomb_field = require("spec.support.bomb_field")
local joysticks = require("engine.joysticks")
local grid = require("level_layout.grid")
local mad_bombers = require("mad_bombers")

local STEP = bomb_field.STEP
local FLOWN_IN_A_STEP = 180 * STEP

local is_down_before
setup(function()
    is_down_before = lutro.joystick.isDown
end)
teardown(function()
    lutro.joystick.isDown = is_down_before
end)

--- A mad bomber's cart with its cannon ready, and the button that fires it.
local function new_cannon()
    joysticks.setup()
    local cannon = {field = bomb_field.empty(), held = false}
    cannon.carts = mad_bombers.new(cannon.field.bombs)
    cannon.carts:ensure_exist_for(1, "kotetsu")
    cannon.cart = cannon.carts.by_player[1]
    lutro.joystick.isDown = function(_, button)
        return cannon.held and button == joysticks.BUTTONS.R
    end

    function cannon:step()
        self.carts:update(STEP)
        self.field:step()
        joysticks.update(STEP)
    end

    function cannon:run(seconds)
        for _ = 1, math.floor(seconds / STEP + 0.5) do
            self:step()
        end
    end

    --- The bomb in the air, one step after it was shot.
    function cannon:shot()
        return self.field:in_air()
    end

    --- Holds the button until the cannon fires, and gives the seconds that took.
    function cannon:hold_until_it_fires()
        local steps = 0
        self.held = true
        while not self:shot() do
            self:step()
            steps = steps + 1
        end
        self.held = false
        return steps * STEP
    end

    function cannon:tap()
        self.held = true
        self:run(2 * STEP)
        self.held = false
        self:step()
    end

    function cannon:run_until_bomb_is_gone()
        local bombs = self.field.bombs
        while not (bombs.in_air:is_empty() and bombs.on_ground:is_empty()) do
            self:step()
        end
    end

    return cannon
end

local function tiles_left_to_fly(shot)
    local left = shot:get_position():distance_to(shot.target) + FLOWN_IN_A_STEP
    return left / grid.TILE_SIZE
end

describe("a mad bomber's cannon", function()
    it("shoots 3 tiles from the cart on a tap, at 180 px a second", function()
        local cannon = new_cannon()
        cannon:tap()
        assert.near(3, tiles_left_to_fly(cannon:shot()), 0.001)
    end)

    it("shoots from the ground", function()
        local cannon = new_cannon()
        cannon:tap()
        assert.is_true(cannon:shot().trajectory.height < 6)
    end)

    it("fires by itself after 0.53 s, 7 tiles from the cart", function()
        local cannon = new_cannon()
        local held_for = cannon:hold_until_it_fires()
        assert.near(32 / 60, held_for, 0.001)
        assert.near(7, tiles_left_to_fly(cannon:shot()), 0.001)
    end)

    it("is ready again 2.6 s after its bomb goes off", function()
        local cannon = new_cannon()
        cannon:tap()
        cannon:run_until_bomb_is_gone()
        cannon:run(2.5)
        assert.are_not.equal("ready", cannon.cart.cannon)
        cannon:run(0.2)
        assert.are.equal("ready", cannon.cart.cannon)
    end)
end)
