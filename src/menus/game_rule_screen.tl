local scenes = require("scenes")
local choices = require("menus.choices")
local srceens = require("menus.screens")
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
    local function enter_player_settings_screen(ctx: Scene)
        scenes.set(player_setting_screen.new(ctx))
    end
    local function enter_timing_settings_screen(ctx: Scene)
        scenes.set(timing_settings_screen.new(ctx))
    end
    local function enter_load_rules_screen(ctx: Scene)
        scenes.set(load_rules_screen.new(ctx, previous_screen))
    end

    return srceens.new({
        choices.new_done(
            "load ruleset", 50, enter_load_rules_screen
        ),
        choices.new_done(
            "item rules", 70, enter_item_settings_screen
        ),
        choices.new_done(
            "player rules", 90, enter_player_settings_screen
        ),
        choices.new_done(
            "timing rules", 110, enter_timing_settings_screen
        ),

        choices.new_done("back", 180, done)
    })
end

return game_rule_screen
