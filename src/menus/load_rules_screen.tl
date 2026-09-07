local scenes = require("engine.scenes")
local choices = require("menus.choices")
local screens = require("menus.screens")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen
local type RulesetName = settings.RulesetName

local load_rules_screen = {}

function load_rules_screen.new(previous_screen: Scene, start_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end
    local function load_ruleset(name: RulesetName): function(ctx: Scene)
        return function(_: Scene)
            settings.set_ruleset(name)
            scenes.set(start_screen)
        end
    end
    local function load_debug_kick_rules()
        settings.set_game_rules_kick_debug()
        scenes.set(start_screen)
    end
    local function load_debug_lightning_bomb_rules()
        settings.set_game_rules_lightning_bomb_debug()
        scenes.set(start_screen)
    end
    local function load_debug_performance_rules()
        settings.set_debug_performance()
        scenes.set(start_screen)
    end
    local function load_debug_dino_rules()
        settings.set_debug_dinos()
        scenes.set(start_screen)
    end

    return screens.new(
        {
            choices.new_done("insanity", 50, load_ruleset("insanity")),
            choices.new_done("dino madness", 65, load_ruleset("dino_madness")),
            choices.new_done("bomb stack", 80, load_ruleset("bomb_stack")),
            choices.new_done("default", 95, load_ruleset("default")),
            choices.new_done("debug dinos", 110, load_debug_dino_rules),
            choices.new_done("debug kick", 125, load_debug_kick_rules),
            choices.new_done(
                "debug lightning-bomb", 140, load_debug_lightning_bomb_rules
            ),
            choices.new_done("debug performance", 155, load_debug_performance_rules),
            choices.new_done("back", 195, done),
        },
        done
    )
end

return load_rules_screen
