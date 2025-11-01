local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local items = require("menus.items")
local srceens = require("menus.screens")

local game_rule_screen = {}

function game_rule_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local nbr_soft_blocks_selected = items.new_selection(settings.nbr_soft_blocks, 0, 120)
    return srceens.new({
        choices.new_integer(
            "nbr. soft blocks", 50, nbr_soft_blocks_selected, settings.set_nbr_soft_blocks
        ),
        choices.new_boolean(
            "start with kick", 70, settings.start_with_kick, settings.set_start_with_kick
        ),
        choices.new_done("back", 180, done)
    })
end

return game_rule_screen
