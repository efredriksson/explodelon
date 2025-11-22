local audio = require("audio")
local characters = require("characters")
local const = require("const")
local game = require("game")
local items = require("menus.items")
local itertools = require("itertools")
local player_selection = require("player_selection")
local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local screens = require("menus.screens")
local debug_screen = require("menus.debug_screen")
local game_rule_screen = require("menus.game_rule_screen")

local start_screen = {}


function start_screen.new(): MenuScreen
    local nbr_player_selected = items.new_integer_selection(settings.number_of_players, 2, const.MAX_PLAYERS)
    local choices_values: {PlayerSelectionMethod} = {"on", "off", "keep"}
    local player_selection_choice = items.new_enum(choices_values)
    local map_selection_choice = items.new_enum({"football", "factory"})
    local menu_screen: MenuScreen

    local function done(_: Scene)
        audio.stop()
        if settings.player_selection == "on" then
            characters.clear_selections()
            scenes.set(player_selection.setup())
        elseif settings.player_selection == "off" then
            characters.auto_select_for(settings.number_of_players)
            scenes.set(game.new(nil))
        else
            scenes.set(player_selection.setup())
        end

        -- Set default as 'keep' if there is a selection for nbr of players:
        settings.player_selection = "keep"
    end
    local function go_back(_: Scene) end -- Does nothing at start screen
    local function enter_debug_screen(ctx: Scene)
        scenes.set(debug_screen.new(ctx))
    end
    local function enter_game_rules_screen(ctx: Scene)
        scenes.set(game_rule_screen.new(ctx))
    end
    local function update_player_selection_choices()
        if settings.number_of_players ~= #characters.get_selections() then
            -- Make sure you can't use 'keep' if number of players are not same as selected for
            if player_selection_choice.max == #choices_values then
                player_selection_choice:reduce_max_val()
            end
        else
            -- Otherwise you can use 'keep'
            player_selection_choice.max = #choices_values
        end
    end
    local function set_number_of_players(val: integer)
        settings.set_number_of_players(val)
        update_player_selection_choices()
    end
    local function on_load()
        nbr_player_selected.value = settings.number_of_players
        player_selection_choice.value = itertools.find(settings.player_selection, choices_values)
        update_player_selection_choices()
    end

    menu_screen = screens.new({
        choices.new_integer("number of players", 50, nbr_player_selected, set_number_of_players),
        choices.new_enum("player selection", 70, player_selection_choice, settings.set_player_selection),
        choices.new_enum("map", 90, map_selection_choice, settings.set_map),
        choices.new_done("game rules", 110, enter_game_rules_screen),
        choices.new_done("debug settings", 130, enter_debug_screen),
        choices.new_done("start game", 180, done)
    }, go_back, on_load)
    return menu_screen
end

return start_screen
