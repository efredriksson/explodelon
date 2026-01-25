local scenes = require("engine.scenes")
local settings = require("settings")
local choices = require("menus.choices")
local items = require("menus.items")
local screens = require("menus.screens")

local item_drops_screen = {}

function item_drops_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local current_idx_by_val: {number: integer} = {}
    local numbers_to_select_from: {number} = {}
    for idx=1, 100 do
        local val = (idx - 1) * 0.01 -- Percentage resolution
        current_idx_by_val[val] = idx
        numbers_to_select_from[idx] = val
    end

    local function get_start(val: number): integer
        return current_idx_by_val[val] or 0
    end

    local spawn_settings = settings.game_rules.items.spawn_rates
    local nbr_bombs_selected = items.new_number_selection(get_start(spawn_settings.bomb), numbers_to_select_from)
    local nbr_fires_selected = items.new_number_selection(get_start(spawn_settings.fire), numbers_to_select_from)
    local nbr_speeds_selected = items.new_number_selection(get_start(spawn_settings.speed), numbers_to_select_from)
    local nbr_kicks_selected = items.new_number_selection(get_start(spawn_settings.kick), numbers_to_select_from)
    local nbr_lightning_bombs_selected = items.new_number_selection(get_start(spawn_settings.lightning_bomb), numbers_to_select_from)
    return screens.new({
        choices.new_number(
            "drop pct. of bombs", 50, nbr_bombs_selected, settings.set_spawn_of_bombs
        ),
        choices.new_number(
            "drop pct. of fire", 65, nbr_fires_selected, settings.set_spawn_of_fire
        ),
        choices.new_number(
            "drop pct. of speed", 80, nbr_speeds_selected, settings.set_spawn_of_speed
        ),
        choices.new_number(
            "drop pct. of kicks", 95, nbr_kicks_selected, settings.set_spawn_of_kick
        ),
        choices.new_number(
            "drop pct. of lightning-bombs", 110, nbr_lightning_bombs_selected, settings.set_spawn_of_lightning_bombs
        ),
        choices.new_done("back", 180, done)
    }, done)
end

return item_drops_screen
