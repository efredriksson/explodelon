require("const")
require("scene")

local record MenuSelection
   value: integer
   min: integer
   max: integer
end

local record MenuButton
   text: string
   y_pos: number
end

function MenuButton.new(text: string, y_pos: number): MenuButton
   local self: MenuButton = setmetatable({}, { __index = MenuButton })
   self.text = text
   self.y_pos = y_pos
   return self
end

function MenuSelection:increment(): boolean
    local new_val = self.value + 1
    self.value = math.min(new_val, self.max)
    return new_val <= self.max
end

function MenuSelection:decrement(): boolean
    local new_val = self.value - 1
    self.value = math.max(new_val, self.min)
    return new_val >= self.min
end

function MenuSelection.new(start: integer, min: integer, max: integer): MenuSelection
   local self: MenuSelection = setmetatable({}, { __index = MenuSelection })
   self.value = start
   self.min = min or 0
   self.max = max or 100
   return self
end

global player_selection = MenuSelection.new(4, 2, 8)
global menu_selection = MenuSelection.new(1, 1, 2)

local function print_centered(text: string, font: Font, y: number)
	lutro.graphics.setFont(font)
	lutro.graphics.printf(text, 0, y, MAP_WIDTH, "center")
end

global function menu_load_resources()
    local font_symbols = " abcdefghijklmnopqrstuvwxyz0123456789.!'-:*"
    global black_font = lutro.graphics.newImageFont("assets/black_imgfont.png", font_symbols)
    global white_font = lutro.graphics.newImageFont("assets/white_imgfont.png", font_symbols)

    global ok_sound = lutro.audio.newSource("assets/menu_good.wav", "static")
end

global function menu_gamepadpressed(button: GamepadButton)
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

global function menu_draw()
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
