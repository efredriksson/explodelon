local scenes = require("engine.scenes")
local beginner_settings_screen = require("menus.beginner_settings_screen")
local choices = require("menus.choices")
local dino_settings_screen = require("menus.dino_setting_screen")
local ice_settings_screen = require("menus.ice_settings_screen")
local item_spawn_screen = require("menus.item_drops_screen")
local item_setting_screen = require("menus.item_setting_screen")
local player_setting_screen = require("menus.player_setting_screen")
local screens = require("menus.screens")
local timing_settings_screen = require("menus.timing_settings_screen")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen

local NO_WARNING = ""
local REPLACES_HOUSE_RULES = "changes here replace current house rules"

local function house_rules_warning(): string
    if settings.tweaking_replaces_house_rules() then
        return REPLACES_HOUSE_RULES
    end
    return NO_WARNING
end

local game_rule_screen = {}

function game_rule_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        settings.finish_tweaking()
        scenes.set(previous_screen)
    end
    local function enter_item_settings_screen(ctx: Scene)
        scenes.set(item_setting_screen.new(ctx))
    end
    local function enter_item_spawn_screen(ctx: Scene)
        scenes.set(item_spawn_screen.new(ctx))
    end
    local function enter_dino_settings_screen(ctx: Scene)
        scenes.set(dino_settings_screen.new(ctx))
    end
    local function enter_player_settings_screen(ctx: Scene)
        scenes.set(player_setting_screen.new(ctx))
    end
    local function enter_timing_settings_screen(ctx: Scene)
        scenes.set(timing_settings_screen.new(ctx))
    end
    local function enter_ice_settings_screen(ctx: Scene)
        scenes.set(ice_settings_screen.new(ctx))
    end
    local function enter_beginner_settings_screen(ctx: Scene)
        scenes.set(beginner_settings_screen.new(ctx))
    end

    return screens.new_with_note(
        {
            choices.new_done("item rules", 50, enter_item_settings_screen),
            choices.new_done("item drop rules", 65, enter_item_spawn_screen),
            choices.new_done("dino rules", 80, enter_dino_settings_screen),
            choices.new_done("player rules", 95, enter_player_settings_screen),
            choices.new_done("timing rules", 110, enter_timing_settings_screen),
            choices.new_done("ice rules", 125, enter_ice_settings_screen),
            choices.new_done("beginner help", 140, enter_beginner_settings_screen),
            choices.new_done("back", 155, done),
        },
        done,
        screens.new_note(house_rules_warning, 188)
    )
end

return game_rule_screen
