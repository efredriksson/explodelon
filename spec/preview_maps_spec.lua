package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
require("options_selection").load_assets()
local closed_tiles = require("closed_tiles")
local grid = require("level_layout.grid")
local maps = require("preview.maps")
local scripted_battle = require("preview.scripted_battle")

local FRAME = 1 / 60

--- Runs a map's preview for one cycle and passes if `happens` was true of the battle at some step of it.
local function within_one_cycle(map, happens)
    return function()
        local battle = scripted_battle.new(maps.scenery_for(map), maps.choreography_for(map))
        local happened = false
        while not battle:taught_once() do
            happened = happened or happens(battle)
            battle:update(FRAME)
        end
        battle:leave()
        assert.is_true(happened)
    end
end

local function victim_is_dying(battle)
    return battle.choreography.victim.action == "dying"
end

local function kills_its_victim(map)
    return within_one_cycle(map, victim_is_dying)
end

local NEIGHBOURS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

--- Whether blocks and bombs leave the victim no way to walk to the arena's top-left corner. The tile the
-- victim is on counts as open: the chaser drops a bomb on it as the two glide past each other.
local function victim_is_walled_in(battle)
    local closed = closed_tiles.new(
        battle.hard_blocks.on_ground.set, battle.soft_blocks.on_ground.set, battle.bombs.on_ground.set
    )
    local reached = {}
    local function walk_on_from(column, row)
        reached[column .. ":" .. row] = true
        for _, offset in ipairs(NEIGHBOURS) do
            local next_column, next_row = column + offset[1], row + offset[2]
            if closed:is_open(next_column, next_row) and not reached[next_column .. ":" .. next_row] then
                walk_on_from(next_column, next_row)
            end
        end
    end
    walk_on_from(grid.tile_indices(battle.choreography.victim.position))
    return not reached["0:0"]
end

describe("ice rink preview", function()
    it("walls the victim in with bombs within one cycle", within_one_cycle("ice_rink", victim_is_walled_in))
    it("kills the victim it walled in within one cycle", kills_its_victim("ice_rink"))
end)

describe("factory preview", function()
    it("sets off its kicked bombs one after another onto the victim within one cycle", kills_its_victim("factory"))
end)

describe("football preview", function()
    it("kills the victim with a goal blast within one cycle", kills_its_victim("football"))
end)

describe("bouncing preview", function()
    it("blows up the victim it pins within one cycle", kills_its_victim("bouncing"))
end)
