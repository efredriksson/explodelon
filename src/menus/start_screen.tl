local scenes = require("engine.scenes")
local itertools = require("itertools")
local map_setup = require("map_setup")
local choices = require("menus.choices")
local debug_screen = require("menus.debug_screen")
local screens = require("menus.screens")
local update_sceen = require("menus.update_screen")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen
local type MenuChoice = choices.MenuChoice

local start_screen = {}

function start_screen.new(): MenuScreen
    -- The menu music is left running so it carries over into the picker screens;
    -- player selection stops it when it starts its own.
    local function done(_: Scene)
        scenes.set(map_setup.new())
    end
    -- Root of the menus, there is nowhere to go back to.
    local function go_back(_: Scene)
    end
    local function enter_debug_screen(_: Scene)
        scenes.set(debug_screen.new())
    end
    local function enter_update_screen(_: Scene)
        scenes.set(update_sceen.new())
    end

    local function update_row_if_recalbox(): {MenuChoice}
        if update_sceen.is_recalbox() then
            return {choices.new_done("check for updates", 110, enter_update_screen)}
        end
        return {}
    end

    local menu_choices: {MenuChoice} = itertools.combine(
        {
            choices.new_boolean("teams", 50, settings.teams, settings.set_teams),
            choices.new_done("debug settings", 95, enter_debug_screen),
        },
        update_row_if_recalbox(),
        {choices.new_done("set up battle", 180, done)}
    )

    return screens.new(menu_choices, go_back, #menu_choices)
end

return start_screen
