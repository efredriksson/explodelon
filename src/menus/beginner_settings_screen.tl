local scenes = require("engine.scenes")
local choices = require("menus.choices")
local items = require("menus.items")
local screens = require("menus.screens")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen

local beginner_settings_screen = {}

function beginner_settings_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    -- A grace of 0 seconds is the "off" setting: _should_petrify never fires.
    local grace_options: {number} = {0, 3, 5, 8, 10, 15}
    local stone_options: {number} = {3, 5, 8, 10}

    local player_settings = settings.game_rules.players
    local grace_selection = items.new_number_selection_for_value(
        player_settings.petrify_grace_seconds, grace_options
    )
    local stone_selection = items.new_number_selection_for_value(
        player_settings.petrify_stone_seconds, stone_options
    )

    return screens.new(
        {
            choices.new_number(
                "grace seconds", 50, grace_selection, settings.set_petrify_grace_seconds
            ),
            choices.new_number(
                "stone seconds", 70, stone_selection, settings.set_petrify_stone_seconds
            ),
            choices.new_done("back", 180, done),
        },
        done
    )
end

return beginner_settings_screen
