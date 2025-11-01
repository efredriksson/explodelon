local items = require("menus.items")
local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local srceens = require("menus.screens")

local player_settings_screen = {}

function player_settings_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local start_speed_selected = items.new_integer_selection(settings.start_speed, 20, 100)
    return srceens.new({
        choices.new_boolean(
            "start position random", 50, settings.start_position_shuffle, settings.set_start_position_shuffle
        ),
        choices.new_boolean(
            "mad bombers", 70, settings.mad_bombers, settings.set_mad_bombers
        ),
        choices.new_integer(
            "start speed", 90, start_speed_selected, settings.set_start_speed
        ),
        choices.new_boolean(
            "start with kick", 110, settings.start_with_kick, settings.set_start_with_kick
        ),
        choices.new_done("back", 180, done)
    })
end

return player_settings_screen
