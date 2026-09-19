local audio = require("engine.audio")
local points = require("engine.geometry.points")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local choices = require("menus.choices")
local items = require("menus.items")
local painting = require("menus.painting")
local screen = require("screen")

local type Color = images.Color
local type MenuFont = fonts.MenuFont
local type Point = points.Point
local type Scene = scenes.Scene
local type MenuSelection = items.MenuSelection
local type MenuChoice = choices.MenuChoice

local gray_font: MenuFont
local white_font: MenuFont
local note_font: MenuFont
local music: Source
local ok_sound: Source
local background: Image

local PANEL_TINT: Color = {200, 200, 200}
local PANEL_ALPHA = 175

local NOTHING_TO_SAY = ""
local NOTE_RULE_INSET = 30
local NOTE_RULE_GAP = 13

local type NoteText = function(): string

local record MenuNote
    position: Point
    text: NoteText
end

local record MenuScreen is Scene
    menu_choices: {MenuChoice}
    menu_selection: MenuSelection<integer>
    go_back: function(Scene)
    note: MenuNote
end

local screens = {MenuScreen = MenuScreen}

function screens.new_note(text: NoteText, y_pos: integer): MenuNote
    local self: MenuNote = setmetatable({}, {__index = MenuNote})
    self.position = points.new(0, y_pos)
    self.text = text
    return self
end

function MenuNote:draw()
    local line = self.text()
    if line == NOTHING_TO_SAY then
        return
    end

    painting.draw_hline(
        NOTE_RULE_INSET,
        screen.WIDTH - 1 - NOTE_RULE_INSET,
        self.position.y - NOTE_RULE_GAP,
        painting.BLACK
    )
    note_font:print_centered(line, screen.WIDTH, self.position)
end

local function new_screen(
    menu_choices: {MenuChoice},
    go_back?: function(Scene),
    selected?: integer,
    note?: MenuNote
): MenuScreen
    local self: MenuScreen = setmetatable({}, {__index = MenuScreen})
    self.menu_choices = menu_choices
    self.menu_selection = items.new_integer_selection(
        selected or 1, 1, #self.menu_choices
    )
    self.go_back = go_back or function(_: Scene) end
    self.note = note
    return self
end

function screens.new(
    menu_choices: {MenuChoice}, go_back?: function(Scene), selected?: integer
): MenuScreen
    return new_screen(menu_choices, go_back, selected)
end

function screens.new_with_note(
    menu_choices: {MenuChoice}, go_back: function(Scene), note: MenuNote
): MenuScreen
    return new_screen(menu_choices, go_back, nil, note)
end

function screens.load_assets()
    white_font = fonts.new_menu_white_outlined()
    gray_font = fonts.new_menu_gray_outlined()
    note_font = fonts.new_menu_colored_outlined(painting.AMBER)
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

    if joysticks.is_pressed_any(joysticks.BUTTONS.DOWN) then
        ok_action = self.menu_selection:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.UP) then
        ok_action = self.menu_selection:decrement()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        self.go_back(self)
    end

    if ok_action then
        ok_sound:play()
    end
end

function MenuScreen:draw()
    lutro.graphics.draw(background)
    local x_pad = 20
    local y_pad = 10
    painting.set_color(PANEL_TINT, PANEL_ALPHA)
    lutro.graphics.rectangle(
        "fill", x_pad, y_pad, screen.WIDTH - 2 * x_pad, screen.HEIGHT - 2 * y_pad
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

    if self.note then
        self.note:draw()
    end
end

function MenuScreen:load()
end

return screens
