require("scenes")
require("menus.choices")
local audio = require("audio")
local const = require("const")
local fonts = require("fonts")
local joysticks = require("joysticks")
local items = require("menus.items")


local JOYPAD = joysticks.buttons()
local gray_font: MenuFont
local white_font: MenuFont
local music: Source
local ok_sound: Source
local background: Image


global record MenuScreen is Scene
    menu_choices: {MenuChoice}
    menu_selection: MenuSelection<integer>
    on_load: function()
    go_back: function(Scene)
end

local screens = {}

function screens.new(menu_choices: {MenuChoice}, go_back?: function(Scene), on_load?: function()): MenuScreen
    local self: MenuScreen = setmetatable({}, { __index = MenuScreen })
    self.menu_choices = menu_choices
    self.menu_selection = items.new_integer_selection(1, 1, #self.menu_choices)
    self.on_load = on_load or function() end
    self.go_back = go_back or function(_: Scene) end
    return self
end

function screens.load_assets()
    white_font = fonts.new_menu_white_outlined()
    gray_font = fonts.new_menu_gray_outlined()
    background = lutro.graphics.newImage("assets/menu-background.png")
    ok_sound = items.ok_sound()
    music = audio.new_source("assets/music/menus.ogg", "static")
    music:setLooping(true)
    music:setVolume(0.75)
end

function MenuScreen:update(_: number)
    if not music:isPlaying() then
        music:play()
    end

    local ok_action = false

    for line_idx, line in ipairs(self.menu_choices) do
        if self.menu_selection:get_value() == line_idx then
            ok_action = line:update(self)
        end
    end
    
    if joysticks.is_pressed_any(JOYPAD.DOWN) then
        ok_action = self.menu_selection:increment()
    elseif joysticks.is_pressed_any(JOYPAD.UP) then
        ok_action = self.menu_selection:decrement()
    elseif joysticks.is_pressed_any(JOYPAD.A) then
        self.go_back(self)
    end

    if ok_action then
        ok_sound:play()
    end
end

function MenuScreen:draw()
    lutro.graphics.draw(background)
    lutro.graphics.setColor(200, 200, 200, 175)
    local x_pad = 20
    local y_pad = 10
	lutro.graphics.rectangle(
        "fill", x_pad, y_pad, const.MAP_WIDTH - 2*x_pad, const.MAP_HEIGHT - 2*y_pad
    )

    local function get_font(line_idx): MenuFont
        if line_idx == self.menu_selection:get_value() then
            return white_font
        else
            return gray_font
        end
    end

    for line_idx, line in ipairs(self.menu_choices) do
        local font = get_font(line_idx)
        line:draw(font)
    end
end

function MenuScreen:load()
    self.on_load()
end

return screens
