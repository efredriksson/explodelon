package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
require("options_selection").load_assets()
local maps = require("preview.maps")
local scripted_battle = require("preview.scripted_battle")

local FRAME = 1 / 60

--- Runs a map's preview for one cycle and passes if its victim was killed in it.
local function kills_its_victim(map)
    return function()
        local battle = scripted_battle.new(maps.scenery_for(map), maps.choreography_for(map))
        local caught = false
        while not battle:taught_once() do
            caught = caught or battle.choreography.victim.action == "dying"
            battle:update(FRAME)
        end
        battle:leave()
        assert.is_true(caught)
    end
end

describe("ice rink preview", function()
    it("seals the victim in with bombs within one cycle", kills_its_victim("ice_rink"))
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
