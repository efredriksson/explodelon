local character_sprites = require("character_sprites")
local const = require("const")
local game = require("game")
local items = require("menus.items")
local player_selection = require("player_selection")
local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local srceens = require("menus.screens")

local start_screen = {}

function start_screen.new(): MenuScreen
    local function done()
        if settings.player_selection then
            scenes.set(player_selection.setup(settings.number_of_players))
        else
            scenes.set(game.setup(character_sprites.get(settings.number_of_players)))
        end
    end

    local nbr_player_selected = items.new_selection(4, 2, const.MAX_PLAYERS)
    return srceens.new({
        choices.new_integer("number of players", 50, nbr_player_selected, settings.set_number_of_players),
        choices.new_boolean("player selection", 70, true, settings.set_player_selection),
        choices.new_done("start game", 180, done)
    })
end

return start_screen
