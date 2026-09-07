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
    return screens.new(
        {
            choices.new_done("insanity", 50, load_ruleset("insanity")),
            choices.new_done("dino madness", 65, load_ruleset("dino_madness")),
            choices.new_done("bomb stack", 80, load_ruleset("bomb_stack")),
            choices.new_done("default", 95, load_ruleset("default")),
            choices.new_done("back", 180, done),
        },
        done
    )
end

return load_rules_screen
