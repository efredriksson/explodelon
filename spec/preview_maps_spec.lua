package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
require("options_selection").load_assets()
local maps = require("preview.maps")
local scripted_battle = require("preview.scripted_battle")

local FRAME = 1 / 60

describe("ice rink preview", function()
    it("seals the victim in with bombs within one cycle", function()
        local battle = scripted_battle.new(maps.scenery_for("ice_rink"), maps.choreography_for("ice_rink"))
        local caught = false
        while not battle:taught_once() do
            caught = caught or battle.choreography.victim.action == "dying"
            battle:update(FRAME)
        end
        battle:leave()
        assert.is_true(caught)
    end)
end)
