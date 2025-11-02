require("scenes")
require("menus.choices")
local const = require("const")
local fonts = require("fonts")
local joysticks = require("joysticks")
local items = require("menus.items")


local JOYPAD = joysticks.buttons()
local black_font: MenuFont
local white_font: MenuFont
local ok_sound: Source


global record MenuScreen is Scene
    menu_choices: {MenuChoice}
    menu_selection: MenuSelection<integer>
end

local screens = {}

function screens.new(menu_choices: {MenuChoice}): MenuScreen
    local self: MenuScreen = setmetatable({}, { __index = MenuScreen })
    self.menu_choices = menu_choices
    self.menu_selection = items.new_integer_selection(1, 1, #self.menu_choices)
    return self
end

function screens.load_assets()
    white_font = fonts.new_menu_white()
    black_font = fonts.new_menu_black()
    ok_sound = items.ok_sound()
end

function MenuScreen:update(_: number)
    local ok_action = false

    for line_idx, line in ipairs(self.menu_choices) do
        if self.menu_selection:get_value() == line_idx then
            ok_action = line:update(self)
        end
    end
    
    if joysticks.is_pressed(1, JOYPAD.DOWN) then
        ok_action = self.menu_selection:increment()
    elseif joysticks.is_pressed(1, JOYPAD.UP) then
        ok_action = self.menu_selection:decrement()
    end

    if ok_action then
        ok_sound:play()
    end
end

function MenuScreen:draw()
    lutro.graphics.setColor(200, 200, 200)
	lutro.graphics.rectangle("fill", 0, 0, const.MAP_WIDTH, const.MAP_HEIGHT)

    local function get_font(line_idx): MenuFont
        if line_idx == self.menu_selection:get_value() then
            return white_font
        else
            return black_font
        end
    end

    for line_idx, line in ipairs(self.menu_choices) do
        local font = get_font(line_idx)
        line:draw(font)
    end
end

return screens
