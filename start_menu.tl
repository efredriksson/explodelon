require("const")
require("scene")
require("fonts")
require("menu_items")
require("character_sprites")

local player_selection = MenuSelection.new(4, 2, 8)
local menu_selection = MenuSelection.new(1, 1, 2)
local black_font: MenuFont
local white_font: MenuFont
local ok_sound: Source

local function menu_load_resources()
    white_font = get_menu_white_font(MAP_WIDTH)
    black_font = get_menu_black_font(MAP_WIDTH)
    ok_sound = get_ok_sound()
end

local function menu_gamepadpressed(button: GamepadButton)
    local ok_action = false
    if menu_selection.value == 1 then
        if button == "right" then
            ok_action = player_selection:increment()
        elseif button == "left" then
            ok_action = player_selection:decrement()
        end
    end

    if menu_selection.value == 2 then
        if button == "b" then
            set_scene(require("game")(get_sprites(player_selection.value)))
            ok_action = true
        end
    end
    
    if button == "down" then
        ok_action = menu_selection:increment()
    elseif button == "up" then
        ok_action = menu_selection:decrement()
    end

    if ok_action then
        lutro.audio.play(ok_sound)
    end
end

local function menu_draw()
    lutro.graphics.setColor(200, 200, 200)
	lutro.graphics.rectangle("fill", 0, 0, MAP_WIDTH, MAP_HEIGHT)

    local menu_buttons = {
        MenuButton.new("number of players - " .. tostring(player_selection.value), 50),
        MenuButton.new("start game", 180),
    }

    local function get_font(button_index): MenuFont
        if button_index == menu_selection.value then
            return white_font
        else
            return black_font
        end
    end

    for button_index, button in ipairs(menu_buttons) do
        get_font(button_index):print_centered(button.text, Point.new(0, button.y_pos))
    end
end

local module = Scene.new()
module.load = menu_load_resources
module.gamepadpressed = menu_gamepadpressed
module.draw = menu_draw
return module
