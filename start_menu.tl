require("const")
require("scene")
require("fonts")
require("input")
require("menu_items")
require("character_sprites")

local player_selection = MenuSelection.new(4, 2, 8)
local menu_selection = MenuSelection.new(1, 1, 2)
local black_font: MenuFont
local white_font: MenuFont
local ok_sound: Source

local function menu_load_resources()
    white_font = get_menu_white_font()
    black_font = get_menu_black_font()
    ok_sound = get_ok_sound()
end

local function menu_update(_: number)
    local ok_action = false
    if menu_selection.value == 1 then
        if joystick_is_pressed(1, JOYPAD_RIGHT) then
            ok_action = player_selection:increment()
        elseif joystick_is_pressed(1, JOYPAD_LEFT) then
            ok_action = player_selection:decrement()
        end
    end

    if menu_selection.value == 2 then
        if joystick_is_pressed(1, JOYPAD_B) then
            set_scene(require("game")(get_sprites(player_selection.value)))
            ok_action = true
        end
    end
    
    if joystick_is_pressed(1, JOYPAD_DOWN) then
        ok_action = menu_selection:increment()
    elseif joystick_is_pressed(1, JOYPAD_UP) then
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
        MenuLine.new({
            MenuLineColumn.new("", 20),
            MenuLineColumn.new("number of players", 170),
            MenuLineColumn.new("-", 30),
            MenuLineColumn.new(tostring(player_selection.value), 50),
            MenuLineColumn.new("", 50),
        }, 50),
        MenuLine.new({MenuLineColumn.new("start game", MAP_WIDTH)}, 180),
    }

    local function get_font(button_index): MenuFont
        if button_index == menu_selection.value then
            return white_font
        else
            return black_font
        end
    end

    for button_index, button in ipairs(menu_buttons) do
        local font = get_font(button_index)

        local x_pos = 0.0
        for _, column in ipairs(button.columns) do
            font:print_centered(column.text, column.width, Point.new(x_pos, button.y_pos))
            x_pos = x_pos + column.width
        end
    end
end

local module = Scene.new()
module.load = menu_load_resources
module.update = menu_update
module.draw = menu_draw
return module
