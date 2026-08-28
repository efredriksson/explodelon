local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local engine_settings = require("engine.settings")
local choices = require("menus.choices")
local items = require("menus.items")
local screens = require("menus.screens")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen

local debug_screen = {}

function debug_screen.new(previous_screen: Scene): MenuScreen
    local nbr_auto_selected_characters = items.new_integer_selection(
        settings.number_of_auto_selected_characters,
        settings.MINIMUM_PLAYERS,
        joysticks.maxplayers()
    )

    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    return screens.new(
        {
            choices.new_boolean(
                "draw hitboxes",
                50,
                engine_settings.draw_hitboxes,
                engine_settings.set_draw_hitboxs
            ),
            choices.new_boolean(
                "log slow game loop",
                70,
                engine_settings.log_scene_perf,
                engine_settings.set_log_scene_perf
            ),
            choices.new_boolean(
                "log memory usage",
                90,
                engine_settings.log_mem_usage,
                engine_settings.set_log_mem_usage
            ),
            choices.new_boolean(
                "auto-select characters",
                110,
                settings.auto_select_characters,
                settings.set_auto_select_characters
            ),
            choices.new_integer(
                "nbr. to auto-select",
                130,
                nbr_auto_selected_characters,
                settings.set_number_of_auto_selected_characters
            ),
            choices.new_done("back", 180, done),
        },
        done
    )
end

return debug_screen
