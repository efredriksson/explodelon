package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
local bomb_field = require("spec.support.bomb_field")
local hitboxes = require("engine.hitboxes")
local grid = require("level_layout.grid")

local FUSE = bomb_field.FUSE
-- A row of the factory floor without conveyor belts.
local ROW = 3
local FROM = 2

bomb_field.on_the_factory_floor()

local function bystander_on(column)
    local bystander = {position = grid.get_tile_position(column, ROW), was_hit = false}
    function bystander:get_position() return self.position end
    function bystander:hitbox() return hitboxes.new_block(self.position) end
    function bystander:hit_with_bomb() self.was_hit = true end
    return bystander
end

--- An open arena with one bomb on (FROM, ROW), and a bystander wherever `bystander_column` says.
local function new_field(bystander_column)
    local field = bomb_field.new(FROM, ROW)
    if bystander_column then
        field.bystander = bystander_on(bystander_column)
        field.players:add(field.bystander)
        field:close({bystander_column, ROW})
    end

    function field:throw(tiles)
        self.bombs:throw_existing(self.bomb, grid.get_tile_position(FROM + tiles, ROW))
    end

    function field:column()
        return self:tiles_to(self.bomb)[1]
    end

    function field:is_in_air()
        return self:in_air() ~= nil
    end

    return field
end

--- The field `seconds` after its bomb was thrown `tiles` to the right.
local function thrown(tiles, seconds, bystander_column)
    local field = new_field(bystander_column)
    field:throw(tiles)
    field:run(seconds)
    return field
end

describe("a thrown bomb", function()
    it("flies 240 px a second", function()
        local field = thrown(6, 0.2)
        assert.near(FROM + 3, field:column(), 0.01)
    end)

    it("is 47 px up half way through a throw of 6 tiles", function()
        local field = thrown(6, 0.2)
        assert.near(47, field:in_air().trajectory.height, 0.01)
    end)

    it("stays on an open tile", function()
        local field = thrown(6, 0.5)
        assert.are.same({FROM + 6, false}, {field:column(), field:is_in_air()})
    end)

    it("lets its fuse start over when it lands", function()
        local field = new_field()
        field:run(FUSE - 0.5)
        field:throw(2)
        field:run(1)
        assert.is_true(field.bomb.timer > FUSE - 1)
    end)
end)

describe("a thrown bomb that comes down on a closed tile", function()
    --- The field `seconds` after a bomb thrown 3 tiles came down on a closed tile.
    local function come_down(seconds)
        local flight = 0.2
        local field = new_field()
        field:close({FROM + 3, ROW})
        field:throw(3)
        field:run(flight + seconds)
        return field
    end

    it("lies there for 0.033 s", function()
        assert.are.equal(FROM + 3, come_down(0.017):column())
    end)

    it("then hops on at 120 px a second", function()
        local hopped = come_down(0.133):column() - come_down(0.1):column()
        assert.near(4, hopped * grid.TILE_SIZE, 0.01)
    end)

    it("stays on the next open tile", function()
        local field = come_down(0.3)
        assert.are.same({FROM + 4, false}, {field:column(), field:is_in_air()})
    end)
end)

describe("a thrown bomb that comes down on something", function()
    it("hops on from a bomb", function()
        local field = new_field()
        field.bombs:place_static_bomb(grid.get_tile_position(FROM + 2, ROW), 2)
        field:throw(2)
        field:run(0.5)
        assert.are.equal(FROM + 3, field:column())
    end)

    it("hits a player on the tile and hops on", function()
        local field = thrown(2, 0.5, FROM + 2)
        assert.are.same({true, FROM + 3}, {field.bystander.was_hit, field:column()})
    end)

    it("does not hit a player it flies over", function()
        local field = thrown(4, 0.5, FROM + 2)
        assert.are.same({false, FROM + 4}, {field.bystander.was_hit, field:column()})
    end)
end)

describe("a thrown bomb with a flame under it", function()
    it("flies on", function()
        local field = new_field()
        field.bombs.explosions:place_explosion(grid.get_tile_position(FROM + 3, ROW), 1)
        field:throw(6)
        field:run(0.3)
        assert.is_true(field:is_in_air())
    end)
end)

describe("a thrown bomb that comes down in a flame", function()
    it("goes off", function()
        local field = new_field()
        field.bombs.explosions:place_explosion(grid.get_tile_position(FROM + 2, ROW), 1)
        field:throw(2)
        field:run(0.2)
        assert.are.same({true, false}, {field.bombs.on_ground:is_empty(), field:is_in_air()})
    end)
end)

describe("a bomb thrown out of the arena", function()
    it("hops on until it is back in on the other side", function()
        local field = thrown(16, 2)
        assert.are.same({0, false}, {field:column(), field:is_in_air()})
    end)

    --- The field `seconds` after its bomb came down on the row above the arena.
    local function out_at_the_top(seconds)
        local flight = 0.267
        local field = new_field()
        field.bombs:throw_existing(field.bomb, grid.get_tile_position(FROM, -1))
        field:run(flight + seconds)
        return field
    end

    it("is on the second row below the arena after two hops above it", function()
        local field = out_at_the_top(0)
        while field:in_air().hops < 3 do
            field:step()
        end
        assert.are.same({FROM, 12}, field:tiles_to(field.bomb))
    end)

    it("stays on the bottom row of the arena", function()
        local field = out_at_the_top(1.5)
        assert.are.same({{FROM, 10}, false}, {field:tiles_to(field.bomb), field:is_in_air()})
    end)
end)

describe("a thrown bomb on a row with no open tile", function()
    --- A field whose bomb is thrown onto a row that is closed from end to end. It leaves the tiles around
    -- the arena on its 14th hop and on every 20th after that.
    local function hopping()
        local field = new_field()
        local row = {}
        for column = 0, 16 do
            table.insert(row, {column, ROW})
        end
        field:close(unpack(row))
        field:throw(2)

        --- Steps until the bomb has made `hops` hops or is gone, and gives the hops it was last seen with.
        function field:run_to_hop(hops)
            local seen = 0
            while self:in_air() and self:in_air().hops < hops do
                seen = self:in_air().hops
                self:step()
            end
            return seen
        end

        return field
    end

    it("still hops after 64 hops", function()
        local field = hopping()
        field:run_to_hop(70)
        assert.is_true(field:is_in_air())
    end)

    it("is gone when it next leaves the tiles around the arena, without going off", function()
        local field = hopping()
        assert.are.same(
            {74, false, true, 0},
            {
                field:run_to_hop(1000),
                field:is_in_air(),
                field.bombs.on_ground:is_empty(),
                #field.bombs.explosions.on_ground,
            }
        )
    end)
end)
