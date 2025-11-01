local items = require("menus.items")
local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local srceens = require("menus.screens")

local timing_settings_screen = {}

function timing_settings_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local current_idx_by_time: {number: integer} = {
        [60] = 1,
        [90] = 2,
        [120] = 3,
        [150] = 4,
        [180] = 5,
        [210] = 6,
        [240] = 7
    }

    local times_to_select_from: {number} = {}
    for time, idx in pairs(current_idx_by_time) do
        times_to_select_from[idx] = time
    end

    local battle_idx = current_idx_by_time[settings.battle_time] or 5
    local sudden_death_idx = current_idx_by_time[settings.sudden_death_time] or 1
    local battle_time_selection = items.new_time_selection(battle_idx, times_to_select_from)
    local sudden_death_time_selection = items.new_time_selection(sudden_death_idx, times_to_select_from)
    return srceens.new({
        choices.new_time(
            "battle time", 50, battle_time_selection, settings.set_battle_time
        ),
        choices.new_time(
            "sudden death time", 70, sudden_death_time_selection, settings.set_sudden_death_time
        ),
        choices.new_done("back", 180, done)
    })
end

return timing_settings_screen
