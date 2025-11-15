local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local srceens = require("menus.screens")

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
    
    return srceens.new({
        choices.new_done("insanity", 50, load_insanity_rules),
        choices.new_done("default", 70, load_default_rules),
        choices.new_done("debug kick", 90, load_debug_kick_rules),
        choices.new_done("debug lightning-bomb", 110, load_debug_lightning_bomb_rules),
        choices.new_done("back", 180, done)
    })
end

return load_rules_screen
