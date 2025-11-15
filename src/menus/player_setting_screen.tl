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

    local player_settings = settings.game_rules.players
    local start_speed_selected = items.new_integer_selection(player_settings.start_speed, 20, 100)
    local start_with_bombs_selected = items.new_integer_selection(player_settings.start_with_bombs, 1, 20)
    local start_with_lightning_bombs_selected = items.new_integer_selection(player_settings.start_with_lightning_bombs, 1, 20)
    local start_with_fire_selected = items.new_integer_selection(player_settings.start_with_fire, 1, 20)
    return srceens.new({
        choices.new_boolean(
            "start position random", 50, player_settings.start_position_shuffle, settings.set_start_position_shuffle
        ),
        choices.new_boolean(
            "mad bombers", 65, player_settings.mad_bombers.enabled, settings.set_mad_bombers
        ),
        choices.new_boolean(
            "mad bombers dont clear", 80, player_settings.mad_bombers.after_sudden_death, settings.set_mad_bombers_after_sudden_death
        ),
        choices.new_integer(
            "start speed", 95, start_speed_selected, settings.set_start_speed
        ),
        choices.new_boolean(
            "start with kick", 110, player_settings.start_with_kick, settings.set_start_with_kick
        ),
        choices.new_integer(
            "start with bombs", 125, start_with_bombs_selected, settings.set_start_with_bombs
        ),
        choices.new_integer(
            "start with lightning-bombs", 140, start_with_lightning_bombs_selected, settings.set_start_with_lightning_bombs
        ),
        choices.new_integer(
            "start with fire", 155, start_with_fire_selected, settings.set_start_with_fire
        ),
        choices.new_done("back", 180, done)
    })
end

return player_settings_screen
