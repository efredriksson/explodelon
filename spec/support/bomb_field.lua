-- An open arena with one bomb on it, for specs of how bombs move.
--
--     bomb_field.on_the_factory_floor()
--     local field = bomb_field.new(2, 3)
--     field:close({5, 3})
--     field:run(0.5)
--     field:tiles_to(field.bomb)
local busted = require("busted")
local bombs = require("bombs.bombs")
local closed_tiles = require("closed_tiles")
local collision = require("engine.collision")
local grid = require("level_layout.grid")
local settings = require("settings")

local bomb_field = {STEP = 1 / 60, FUSE = 2.5}

local function obstacle_on(tile)
    local position = grid.get_tile_position(tile[1], tile[2])
    return {get_position = function() return position end}
end

--- Runs the specs of a file on the factory floor, which has no football goal that would let a bomb go on
-- past the edge of the arena.
function bomb_field.on_the_factory_floor()
    local map_before
    busted.setup(function()
        map_before = settings.map
        settings.set_map("factory")
    end)
    busted.teardown(function()
        settings.set_map(map_before)
    end)
end

--- A field with no bomb on it.
function bomb_field.empty()
    local field = {
        bombs = bombs.new(true),
        nothing = collision.new_group(),
        closed = closed_tiles.new(),
        players = collision.new_group(),
    }
    field.explodables = collision.new_combined_group(field.bombs.on_ground.set)

    --- Closes the given {column, row} tiles to bombs, and opens every other.
    function field:close(...)
        local obstacles = {}
        for _, tile in ipairs({...}) do
            table.insert(obstacles, obstacle_on(tile))
        end
        self.closed = closed_tiles.new(obstacles)
    end

    function field:step()
        self.bombs:update(
            bomb_field.STEP,
            self.nothing,
            self.explodables,
            self.closed,
            self.players,
            collision.new_lookup(self.bombs.on_ground.set, self.players.set)
        )
    end

    function field:run(seconds)
        for _ = 1, math.floor(seconds / bomb_field.STEP + 0.5) do
            self:step()
        end
    end

    --- The bomb that is in the air, if there is one.
    function field:in_air()
        local _, thrown = next(self.bombs.in_air.set)
        return thrown
    end

    --- Where a bomb is, in tiles from the arena's top-left corner.
    function field:tiles_to(bomb)
        local in_area = grid.position_in_area(bomb.position)
        return {in_area.x / grid.TILE_SIZE, in_area.y / grid.TILE_SIZE}
    end

    return field
end

--- A field with one bomb on (column, row) that goes off after FUSE seconds.
function bomb_field.new(column, row)
    local field = bomb_field.empty()
    field.bombs:place_static_bomb(grid.get_tile_position(column, row), 2)
    local _, bomb = next(field.bombs.on_ground.set)
    field.bomb = bomb
    return field
end

return bomb_field
