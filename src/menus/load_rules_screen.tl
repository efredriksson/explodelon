local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local screens = require("menus.screens")

local load_rules_screen = {}

function load_rules_screen.new(previous_screen: Scene, start_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end
    local function load_default_rules()
        settings.set_game_rules_default()
        scenes.set(start_screen)
    end
    local function load_insanity_rules()
        settings.set_game_rules_insanity()
        scenes.set(start_screen)
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
    
    return screens.new({
        choices.new_done("insanity", 50, load_insanity_rules),
        choices.new_done("default", 70, load_default_rules),
        choices.new_done("debug dinos", 90, load_debug_dino_rules),
        choices.new_done("debug kick", 110, load_debug_kick_rules),
        choices.new_done("debug lightning-bomb", 130, load_debug_lightning_bomb_rules),
        choices.new_done("debug performance", 150, load_debug_performance_rules),
        choices.new_done("back", 180, done)
    }, done)
end

return load_rules_screen
