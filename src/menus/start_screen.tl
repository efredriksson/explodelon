local scenes = require("engine.scenes")
local map_selection = require("map_selection")
local choices = require("menus.choices")
local debug_screen = require("menus.debug_screen")
local game_rule_screen = require("menus.game_rule_screen")
local screens = require("menus.screens")
local update_sceen = require("menus.update_screen")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen
local type MenuChoice = choices.MenuChoice

local start_screen = {}

function start_screen.new(): MenuScreen
    -- The menu music is left running so it carries over into map selection;
    -- that scene stops it once the player commits and moves on.
    local function done(ctx: Scene)
        scenes.set(map_selection.new(ctx))
    end
    -- Root of the menus, there is nowhere to go back to.
    local function go_back(_: Scene)
    end
    local function enter_debug_screen(ctx: Scene)
        scenes.set(debug_screen.new(ctx))
    end
    local function enter_update_screen(ctx: Scene)
        scenes.set(update_sceen.new(ctx))
    end
    local function enter_game_rules_screen(ctx: Scene)
        scenes.set(game_rule_screen.new(ctx))
    end

    local menu_choices: {MenuChoice} = {
        choices.new_boolean("teams", 50, settings.teams, settings.set_teams),
        choices.new_done("game rules", 80, enter_game_rules_screen),
        choices.new_done("debug settings", 95, enter_debug_screen),
    }
    if update_sceen.is_recalbox() then
        table.insert(
            menu_choices,
            choices.new_done("check for updates", 110, enter_update_screen)
        )
    end
    table.insert(menu_choices, choices.new_done("start game", 180, done))

    return screens.new(menu_choices, go_back)
end

return start_screen
