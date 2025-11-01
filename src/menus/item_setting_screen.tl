local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local items = require("menus.items")
local srceens = require("menus.screens")

local item_settings_screen = {}

function item_settings_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local item_settings = settings.game_rules.items
    local nbr_soft_blocks_selected = items.new_integer_selection(item_settings.nbr_soft_blocks, 0, 120)
    local nbr_eggs_selected = items.new_integer_selection(item_settings.nbr_of_eggs, 0, 30)
    local nbr_bombs_selected = items.new_integer_selection(item_settings.nbr_of_items.bomb, 0, 30)
    local nbr_fires_selected = items.new_integer_selection(item_settings.nbr_of_items.fire, 0, 30)
    local nbr_speeds_selected = items.new_integer_selection(item_settings.nbr_of_items.speed, 0, 30)
    local nbr_kicks_selected = items.new_integer_selection(item_settings.nbr_of_items.kick, 0, 30)
    return srceens.new({
        choices.new_integer(
            "nbr. of soft blocks", 50, nbr_soft_blocks_selected, settings.set_nbr_soft_blocks
        ),
        choices.new_integer(
            "nbr. of eggs", 65, nbr_eggs_selected, settings.set_nbr_of_eggs
        ),
        choices.new_integer(
            "nbr. of bombs", 80, nbr_bombs_selected, settings.set_nbr_of_bombs
        ),
        choices.new_integer(
            "nbr. of fire", 95, nbr_fires_selected, settings.set_nbr_of_fire
        ),
        choices.new_integer(
            "nbr. of speed", 110, nbr_speeds_selected, settings.set_nbr_of_speed
        ),
        choices.new_integer(
            "nbr. of kick", 125, nbr_kicks_selected, settings.set_nbr_of_kick
        ),
        choices.new_done("back", 180, done)
    })
end

return item_settings_screen
