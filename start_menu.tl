require("const")
require("scene")
require("menu_items")

local player_selection = MenuSelection.new(4, 2, 8)
local menu_selection = MenuSelection.new(1, 1, 2)
local black_font: Font
local white_font: Font
local ok_sound: Source

local function print_centered(text: string, font: Font, y: number)
	lutro.graphics.setFont(font)
	lutro.graphics.printf(text, 0, y, MAP_WIDTH, "center")
end

local function menu_load_resources()
    local font_symbols = " abcdefghijklmnopqrstuvwxyz0123456789.!'-:*"
    black_font = lutro.graphics.newImageFont("assets/imgfont/black.png", font_symbols)
    white_font = lutro.graphics.newImageFont("assets/imgfont/white.png", font_symbols)
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
            set_scene(require("game")(player_selection.value))
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

    for i, button in ipairs(menu_buttons) do
        if i == menu_selection.value then
            print_centered(button.text, white_font, button.y_pos)
        else
            print_centered(button.text, black_font, button.y_pos)
        end
    end
end

local module = Scene.new()
module.load = menu_load_resources
module.gamepadpressed = menu_gamepadpressed
module.draw = menu_draw
return module
