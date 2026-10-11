package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local bombs = require("bombs.bombs")
local collision = require("engine.collision")
local grid = require("level_layout.grid")

local FRAME = 1 / 60
local FUSE = 2.5
local ROW = 5

--- Bombs on one open row, with no blocks and no players around them.
local function new_field()
    local field = {bombs = bombs.new(true), nothing = collision.new_group(), frame = 0}
    field.blockers = collision.new_combined_group(field.bombs.on_ground.set)
    field.explodables = collision.new_combined_group(field.bombs.on_ground.set)

    function field:place_bomb(column, fire)
        self.bombs:place_static_bomb(grid.get_tile_position(column, ROW), fire)
    end

    function field:step(seconds)
        self.frame = self.frame + 1
        self.bombs:update(
            seconds or FRAME,
            self.blockers,
            self.explodables,
            self.nothing,
            self.nothing,
            self.bombs.on_ground,
            self.nothing,
            collision.new_lookup(self.bombs.on_ground.set)
        )
    end

    function field:bombs_left()
        local count = 0
        for _ in pairs(self.bombs.on_ground.set) do
            count = count + 1
        end
        return count
    end

    function field:step_until_bombs_left(count)
        while self:bombs_left() > count do
            self:step()
        end
        return self.frame
    end

    function field:is_burning(column, row)
        for _, flame in ipairs(self.bombs.explosions.burning) do
            if flame.i == column and flame.j == (row or ROW) then
                return true
            end
        end
        return false
    end

    --- The last frame on which each of the given columns burned, once nothing burns any more.
    function field:last_burning_frames(columns)
        local last = {}
        repeat
            self:step()
            for index, column in ipairs(columns) do
                if self:is_burning(column) then
                    last[index] = self.frame
                end
            end
        until #self.bombs.explosions.on_ground == 0
        return last
    end

    return field
end

describe("a bomb in the way of a flame", function()
    --- A fire-4 bomb at column 4, and a fire-1 bomb two tiles to its right
    -- that is placed too late to go off by its own fuse.
    local function chain()
        local field = new_field()
        field:place_bomb(4, 4)
        for _ = 1, FUSE / 2 / FRAME do
            field:step()
        end
        field:place_bomb(6, 1)
        return field
    end

    it("goes off on the frame the flame reaches it", function()
        local field = chain()
        field:step_until_bombs_left(1)
        -- The left arm lights its second tile as the right arm reaches the bomb.
        while not field:is_burning(2) do
            field:step()
        end
        assert.are.equal(0, field:bombs_left())
    end)

    it("shows its own flames 0.017 s after it goes off", function()
        local field = chain()
        field:step_until_bombs_left(0)
        field:step(0.01)
        assert.is_false(field:is_burning(6))
        field:step(0.02)
        assert.is_true(field:is_burning(6))
    end)

    it("ends the flame, which goes no further than the bomb's own fire", function()
        local field = chain()
        field:step_until_bombs_left(0)
        for _ = 1, 8 do
            field:step()
        end
        assert.is_true(field:is_burning(7))
        assert.is_false(field:is_burning(8))
    end)
end)

describe("a small bomb set off by a much bigger explosion", function()
    --- A fire-12 explosion at column 0 with a fire-1 bomb in its way at column 3. Column 1 burns by the big
    -- explosion alone, column 4 by the bomb's alone.
    local function last_burning_frames(place_big)
        local field = new_field()
        field:place_bomb(3, 1)
        local explosions = field.bombs.explosions
        explosions[place_big](explosions, grid.get_tile_position(0, ROW), 12)
        return unpack(field:last_burning_frames({1, 4}))
    end

    it("burns out first", function()
        local big, small = last_burning_frames("place_explosion")
        assert.is_true(small < big)
    end)

    it("burns as long as an explosion that sustains what it sets off", function()
        local big, small = last_burning_frames("place_sustaining_explosion")
        assert.are.equal(big, small)
    end)
end)

describe("an explosion from a football goal, one column outside the grid", function()
    it("does not hide a flame at the far end of the row above", function()
        local field = new_field()
        field.bombs.explosions:place_explosion(grid.get_tile_position(-1, ROW), 2)
        field.bombs.explosions:place_explosion(grid.get_tile_position(16, ROW - 1), 2)
        field:step(0.03)
        assert.are.same({true, true}, {field:is_burning(-1), field:is_burning(16, ROW - 1)})
    end)
end)

describe("a fire 2 explosion", function()
    it("burns for 0.43 s", function()
        local field = new_field()
        field.bombs.explosions:place_explosion(grid.get_tile_position(8, ROW), 2)
        repeat
            field:step()
        until #field.bombs.explosions.on_ground == 0
        assert.is_true(math.abs(field.frame * FRAME - 26 / 60) < FRAME)
    end)
end)
