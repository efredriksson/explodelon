package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local bomb_field = require("spec.support.bomb_field")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")

-- A kicked bomb slides exactly 2 px at this step.
local STEP = bomb_field.STEP
local FUSE = bomb_field.FUSE
-- A row of the factory floor without conveyor belts.
local ROW = 3
local KICKER = {}

bomb_field.on_the_factory_floor()

--- An open arena with one bomb on (column, ROW) that can be kicked.
local function new_field(column)
    local field = bomb_field.new(column, ROW)

    function field:kick(direction)
        local i, j = grid.tile_indices(self.bomb.position)
        self.bombs:kick_bomb_on(i, j, vectors.from_direction(direction), KICKER, self.closed)
    end

    return field
end

--- The field after its bomb has been kicked right and has slid for `seconds`.
local function kicked_right(column, seconds, ...)
    local field = new_field(column)
    field:close(...)
    field:kick("right")
    field:run(seconds)
    return field
end

describe("a kicked bomb", function()
    it("slides 120 px a second", function()
        local field = kicked_right(2, 0.4)
        assert.are.same({5, ROW}, field:tiles_to(field.bomb))
    end)

    it("stops in the middle of the tile before a closed one", function()
        local field = kicked_right(2, 1, {8, ROW})
        assert.are.same({7, ROW}, field:tiles_to(field.bomb))
        assert.is_false(field.bomb.sliding)
    end)

    it("stops at the edge of the arena", function()
        local field = kicked_right(12, 1)
        assert.are.same({16, ROW}, field:tiles_to(field.bomb))
    end)

    it("stays where it is when the tile behind it is closed", function()
        local field = kicked_right(2, 0.2, {3, ROW})
        assert.are.same({2, ROW}, field:tiles_to(field.bomb))
    end)

    it("jumps back to its tile when the tile it is entering closes", function()
        local field = kicked_right(2, 0.05)
        field:close({3, ROW})
        field:run(STEP)
        assert.are.same({2, ROW}, field:tiles_to(field.bomb))
    end)

    it("turns where it is when kicked back along its line", function()
        local field = kicked_right(2, 0.05)
        field:kick("left")
        field:run(STEP)
        assert.are.same({2.25, ROW}, field:tiles_to(field.bomb))
    end)

    it("jumps to the middle of its tile when kicked across its line", function()
        local field = kicked_right(2, 0.05)
        field:kick("down")
        assert.are.same({2, ROW}, field:tiles_to(field.bomb))
        field:run(0.133)
        assert.are.same({2, ROW + 1}, field:tiles_to(field.bomb))
    end)

    it("stops on its nearest tile when the player who kicked it stops it", function()
        local field = kicked_right(2, 0.167)
        field.bombs:stop_kicked_by(KICKER)
        field:run(0.2)
        assert.are.same({3, ROW}, field:tiles_to(field.bomb))
    end)
end)

describe("a kicked bomb whose fuse runs out as it slides", function()
    --- The column of the explosion of a bomb kicked right from column 2 with `left` seconds on its fuse.
    local function explodes_on(left)
        local field = new_field(2)
        field:run(FUSE - left)
        field:kick("right")
        field:run(left + 0.1)
        return field.bombs.explosions.on_ground[1].i
    end

    it("goes off on the tile behind it when that is the nearest", function()
        assert.are.equal(3, explodes_on(0.17))
    end)

    it("goes off on the tile ahead of it when that is the nearest", function()
        assert.are.equal(4, explodes_on(0.22))
    end)
end)

describe("a kicked bomb that meets another bomb", function()
    --- A bomb on column 2 that is kicked right, with another bomb in its row.
    local function two_bombs(other_column, seconds)
        local field = new_field(2)
        field.bombs:place_static_bomb(grid.get_tile_position(other_column, ROW), 2)
        for _, bomb in pairs(field.bombs.on_ground.set) do
            if bomb ~= field.bomb then
                field.other = bomb
            end
        end
        field:kick("right")
        field:run(seconds)
        return field
    end

    it("stops next to it and passes the kick on", function()
        local field = two_bombs(5, 1.83)
        assert.are.same({{4, ROW}, {16, ROW}}, {field:tiles_to(field.bomb), field:tiles_to(field.other)})
    end)

    it("is not kicked while the other bomb is right behind it, and kicks nothing on", function()
        local field = two_bombs(3, 0.2)
        assert.are.same({{2, ROW}, {3, ROW}}, {field:tiles_to(field.bomb), field:tiles_to(field.other)})
    end)
end)

describe("a conveyor belt on the factory floor", function()
    --- A bomb on (column, 2), on the row of the belt at (12, 2), which points down.
    local function on_belt_row(column, direction, seconds)
        local field = new_field(column)
        field.bomb.position = grid.get_tile_position(column, 2)
        field:kick(direction)
        field:run(seconds)
        return field
    end

    it("turns a bomb that slides over it, without slowing it", function()
        local field = on_belt_row(10, "right", 0.533)
        assert.are.same({12, 4}, field:tiles_to(field.bomb))
    end)

    it("lets a bomb resting on it leave only the way the belt points", function()
        local field = on_belt_row(12, "left", 0.133)
        assert.are.same({12, 3}, field:tiles_to(field.bomb))
    end)
end)
