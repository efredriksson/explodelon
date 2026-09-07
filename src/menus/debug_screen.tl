local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local engine_settings = require("engine.settings")
local choices = require("menus.choices")
local items = require("menus.items")
local screens = require("menus.screens")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen
local type DebugRulesetName = settings.DebugRulesetName

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
    local function load_debug_ruleset(name: DebugRulesetName): function(ctx: Scene)
        return function(_: Scene)
            settings.set_debug_ruleset(name)
            scenes.set(previous_screen)
        end
    end

    return screens.new(
        {
            choices.new_done("debug dinos", 50, load_debug_ruleset("dinos")),
            choices.new_done("debug kick", 65, load_debug_ruleset("kick")),
            choices.new_done(
                "debug lightning-bomb", 80, load_debug_ruleset("lightning_bomb")
            ),
            choices.new_done(
                "debug performance", 95, load_debug_ruleset("performance")
            ),
            choices.new_boolean(
                "draw hitboxes",
                120,
                engine_settings.draw_hitboxes,
                engine_settings.set_draw_hitboxs
            ),
            choices.new_boolean(
                "log slow game loop",
                135,
                engine_settings.log_scene_perf,
                engine_settings.set_log_scene_perf
            ),
            choices.new_boolean(
                "log memory usage",
                150,
                engine_settings.log_mem_usage,
                engine_settings.set_log_mem_usage
            ),
            choices.new_boolean(
                "auto-select characters",
                165,
                settings.auto_select_characters,
                settings.set_auto_select_characters
            ),
            choices.new_integer(
                "nbr. to auto-select",
                180,
                nbr_auto_selected_characters,
                settings.set_number_of_auto_selected_characters
            ),
            choices.new_done("back", 210, done),
        },
        done
    )
end

return debug_screen
