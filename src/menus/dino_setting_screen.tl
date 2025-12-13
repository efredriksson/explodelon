local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local screens = require("menus.screens")

local dino_settings_screen = {}

function dino_settings_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local dino_settings = settings.game_rules.dinos
    return screens.new({
        choices.new_boolean(
            "blue dinos", 50, dino_settings.enabled["blue"], settings.set_dino_enabled("blue")
        ),
        choices.new_boolean(
            "pink dinos", 65, dino_settings.enabled["pink"], settings.set_dino_enabled("pink")
        ),
        choices.new_boolean(
            "purple dinos", 80, dino_settings.enabled["purple"], settings.set_dino_enabled("purple")
        ),
        choices.new_boolean(
            "green dinos", 95, dino_settings.enabled["green"], settings.set_dino_enabled("green")
        ),
        choices.new_boolean(
            "yellow dinos", 110, dino_settings.enabled["yellow"], settings.set_dino_enabled("yellow")
        ),
        choices.new_done("back", 180, done)
    }, done)
end

return dino_settings_screen
