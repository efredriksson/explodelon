local character_sprites = require("character_sprites")
local const = require("const")
local fonts = require("fonts")
local game = require("game")
local points = require("geometry.points")
local joysticks = require("joysticks")
local menu_items = require("menu_items")
local player_selection = require("player_selection")
local scenes = require("scenes")


local JOYPAD = joysticks.buttons()
local nbr_player_selected = menu_items.new_selection(4, 2, const.MAX_PLAYERS)
local player_selection_on = menu_items.new_selection(1, 1, 2)
local menu_selection = menu_items.new_selection(1, 1, 3)
local black_font: MenuFont
local white_font: MenuFont
local ok_sound: Source

local record StartMenu is Scene
end

local start_menu = {}

function start_menu.new(): StartMenu
   local self: StartMenu = setmetatable({}, { __index = StartMenu })
   return self
end

function StartMenu:load()
    white_font = fonts.new_menu_white()
    black_font = fonts.new_menu_black()
    ok_sound = menu_items.ok_sound()
end

function StartMenu:update(_: number)
    local ok_action = false
    if menu_selection.value == 1 then
        if joysticks.is_pressed(1, JOYPAD.RIGHT) then
            ok_action = nbr_player_selected:increment()
        elseif joysticks.is_pressed(1, JOYPAD.LEFT) then
            ok_action = nbr_player_selected:decrement()
        end
    end

    if menu_selection.value == 2 then
        if joysticks.is_pressed(1, JOYPAD.RIGHT) then
            ok_action = player_selection_on:increment()
        elseif joysticks.is_pressed(1, JOYPAD.LEFT) then
            ok_action = player_selection_on:decrement()
        end
    end

    if menu_selection.value == 3 then
        if joysticks.is_pressed(1, JOYPAD.B) then
            if player_selection_on.value == 1 then
                scenes.set(player_selection.setup(nbr_player_selected.value))
            else
                scenes.set(game.setup(character_sprites.get(nbr_player_selected.value)))
            end
            ok_action = true
        end
    end
    
    if joysticks.is_pressed(1, JOYPAD.DOWN) then
        ok_action = menu_selection:increment()
    elseif joysticks.is_pressed(1, JOYPAD.UP) then
        ok_action = menu_selection:decrement()
    end

    if ok_action then
        lutro.audio.play(ok_sound)
    end
end

function StartMenu:draw()
    lutro.graphics.setColor(200, 200, 200)
	lutro.graphics.rectangle("fill", 0, 0, const.MAP_WIDTH, const.MAP_HEIGHT)

    local function player_selection_text(): string
        if player_selection_on.value == 1 then
            return 'on'
        else
            return 'off'
        end
    end

    local menu_buttons = {
        MenuLine.new({
            MenuLineColumn.new("", 20),
            MenuLineColumn.new("number of players", 170),
            MenuLineColumn.new("-", 30),
            MenuLineColumn.new(tostring(nbr_player_selected.value), 50),
            MenuLineColumn.new("", 50),
        }, 50),
        MenuLine.new({
            MenuLineColumn.new("", 20),
            MenuLineColumn.new("player selection", 170),
            MenuLineColumn.new("-", 30),
            MenuLineColumn.new(player_selection_text(), 50),
            MenuLineColumn.new("", 50),
        }, 70),
        MenuLine.new({MenuLineColumn.new("start game", const.MAP_WIDTH)}, 180),
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
            font:print_centered(column.text, column.width, points.new(x_pos, button.y_pos))
            x_pos = x_pos + column.width
        end
    end
end

return start_menu
