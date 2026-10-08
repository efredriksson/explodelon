package.path = "src/?.lua;src/?/init.lua;" .. package.path
require("tl").loader()
require("spec.support.headless_lutro")(1)

require("engine.settings").set_block_size(16)
require("game.battle").load_assets()
require("options_selection").load_assets()
local options = require("preview.options")
local scripted_battle = require("preview.scripted_battle")

local FRAME = 1 / 60

--- Each lesson only moves on to its last phase once it has seen what it teaches
-- happen in the battle, e.g. the green dino's rider has crashed into the wall.
local LAST_PHASE = {
    speed = "loopback",
    bomb = "watching",
    -- The 3.5 s cycle restarts while the walker is still ducking out of the blast,
    -- before it ever reaches "watching"; it did so before the grid walk too.
    kick = "ducking",
    fire = "watching",
    lightning_bomb = "watching",
    egg = "watching",
    dino_blue = "watching",
    dino_pink = "watching",
    dino_green = "watching",
    dino_yellow = "watching",
    dino_purple = "watching",
}

local function reaches_last_phase(subject)
    return function()
        local battle = scripted_battle.new(options.scenery_for(subject), options.choreography_for(subject))
        local reached = {}
        while not battle:taught_once() do
            -- Lessons with a second actor keep the rider's phase as `rider_phase`.
            local lesson = battle.choreography
            reached[lesson.phase or lesson.rider_phase] = true
            battle:update(FRAME)
        end
        battle:leave()
        assert.is_true(reached[LAST_PHASE[subject]] or false, subject .. " never reached " .. LAST_PHASE[subject])
    end
end

describe("menu preview lessons", function()
    for _, subject in ipairs(options.rotation) do
        it(subject .. " plays through to its last phase in one cycle", reaches_last_phase(subject))
    end
end)
