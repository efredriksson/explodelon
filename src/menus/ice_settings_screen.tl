local scenes = require("engine.scenes")
local choices = require("menus.choices")
local items = require("menus.items")
local screens = require("menus.screens")
local settings = require("settings")

local type Scene = scenes.Scene
local type MenuScreen = screens.MenuScreen

local ice_settings_screen = {}

function ice_settings_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    local acceleration_options: {number} = {1, 2, 3, 4, 5, 6, 8}
    local friction_options: {number} = {0.5, 1, 1.5, 2, 3, 4, 6}

    local function find_index(options: {number}, target: number): integer
        for i, v in ipairs(options) do
            if v == target then
                return i
            end
        end
        return 1
    end

    local ice = settings.game_rules.ice
    local acceleration_selection = items.new_number_selection(
        find_index(acceleration_options, ice.acceleration_factor), acceleration_options
    )
    local friction_selection = items.new_number_selection(
        find_index(friction_options, ice.friction_factor), friction_options
    )

    return screens.new(
        {
            choices.new_number(
                "acceleration",
                50,
                acceleration_selection,
                settings.set_ice_acceleration_factor
            ),
            choices.new_number(
                "friction", 70, friction_selection, settings.set_ice_friction_factor
            ),
            choices.new_done("back", 180, done),
        },
        done
    )
end

return ice_settings_screen
