local audio = require("audio")
local character_sprites = require("character_sprites")
local const = require("const")
local game = require("game")
local items = require("menus.items")
local player_selection = require("player_selection")
local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local srceens = require("menus.screens")
local debug_screen = require("menus.debug_screen")
local game_rule_screen = require("menus.game_rule_screen")

local start_screen = {}


function start_screen.new(): MenuScreen
    local function done(_: Scene)
        audio.stop()
        if settings.player_selection then
            scenes.set(player_selection.setup())
        else
            local new_scene = game.setup(nil)
            new_scene:update_players(character_sprites.get_selections(settings.number_of_players))
            scenes.set(new_scene)
        end
    end
    local function enter_debug_screen(ctx: Scene)
        scenes.set(debug_screen.new(ctx))
    end
    local function enter_game_rules_screen(ctx: Scene)
        scenes.set(game_rule_screen.new(ctx))
    end

    local nbr_player_selected = items.new_integer_selection(4, 2, const.MAX_PLAYERS)
    return srceens.new({
        choices.new_integer("number of players", 50, nbr_player_selected, settings.set_number_of_players),
        choices.new_boolean("player selection", 70, true, settings.set_player_selection),
        choices.new_done("game rules", 90, enter_game_rules_screen),
        choices.new_done("debug settings", 110, enter_debug_screen),
        choices.new_done("start game", 180, done)
    })
end

return start_screen
