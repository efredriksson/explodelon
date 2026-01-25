local scenes = require("engine.scenes")
local choices = require("menus.choices")
local screens = require("menus.screens")
local dino_settings_screen = require("menus.dino_setting_screen")
local item_spawn_screen = require("menus.item_drops_screen")
local item_setting_screen = require("menus.item_setting_screen")
local player_setting_screen = require("menus.player_setting_screen")
local timing_settings_screen = require("menus.timing_settings_screen")
local load_rules_screen = require("menus.load_rules_screen")

local game_rule_screen = {}

function game_rule_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
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
    local function enter_load_rules_screen(ctx: Scene)
        scenes.set(load_rules_screen.new(ctx, previous_screen))
    end

    return screens.new({
        choices.new_done(
            "load ruleset", 50, enter_load_rules_screen
        ),
        choices.new_done(
            "item rules", 70, enter_item_settings_screen
        ),
        choices.new_done(
            "item drop rules", 90, enter_item_spawn_screen
        ),
        choices.new_done(
            "dino rules", 110, enter_dino_settings_screen
        ),
        choices.new_done(
            "player rules", 130, enter_player_settings_screen
        ),
        choices.new_done(
            "timing rules", 150, enter_timing_settings_screen
        ),

        choices.new_done("back", 180, done)
    }, done)
end

return game_rule_screen
