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

--- Plays a lesson for one cycle, showing `watch` the battle before each step.
local function play_lesson(subject, watch)
    local battle = scripted_battle.new(options.scenery_for(subject), options.choreography_for(subject))
    while not battle:taught_once() do
        watch(battle)
        battle:update(FRAME)
    end
    battle:leave()
end

local function reaches_last_phase(subject)
    return function()
        local reached = {}
        play_lesson(subject, function(battle)
            -- Lessons with a second actor keep the rider's phase as `rider_phase`.
            local lesson = battle.choreography
            reached[lesson.phase or lesson.rider_phase] = true
        end)
        assert.is_true(reached[LAST_PHASE[subject]] or false, subject .. " never reached " .. LAST_PHASE[subject])
    end
end

describe("menu preview lessons", function()
    for _, subject in ipairs(options.rotation) do
        it(subject .. " plays through to its last phase in one cycle", reaches_last_phase(subject))
    end
end)

--- The yellow dino's lesson is that a stunned bomber cannot walk away from its own bombs.
local function stunned_bomber_dies()
    local died_stunned = false
    play_lesson("dino_yellow", function(battle)
        local victim = battle.choreography.victim
        died_stunned = died_stunned or (victim.action == "dying" and victim:is_stunned())
    end)
    assert.is_true(died_stunned)
end

describe("yellow dino lesson", function()
    it("has the bomber die of its own bombs while the stun cry holds it", stunned_bomber_dies)
end)
