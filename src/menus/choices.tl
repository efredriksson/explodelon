require("fonts")
require("scenes")
local const = require("const")
local points = require("geometry.points")
local joysticks = require("joysticks")
local items = require("menus.items")


local JOYPAD = joysticks.buttons()
local choices = {}

global type MenuChoice = interface
    update: function(self, ctx: Scene): boolean
    draw: function(self, font: MenuFont)
end

local record MenuChoiceImpl<T> is MenuChoice
    selection: MenuSelection<T>
    y_pos: integer
    menu_text: string
    value_change: function(T)
    on_select: function(ctx: Scene)
end

function choices.new_boolean(menu_text: string, y_pos: integer, on_by_default: boolean, callback: function(boolean)): MenuChoiceImpl<boolean>
    local selection = items.new_boolean_selection(on_by_default)

    local self: MenuChoiceImpl<boolean> = setmetatable({}, { __index = MenuChoiceImpl })
    self.y_pos = y_pos
    self.selection = selection
    self.menu_text = menu_text
    self.value_change = callback
    return self
end

function MenuChoiceImpl:update(ctx: Scene): boolean
    local ok_action = false

    local function active_button(button: integer): boolean
        local time_until_fast_change = 0.3
        return joysticks.is_pressed_any(button) or
            joysticks.is_down_for_any(button, time_until_fast_change)
    end

    if self.selection then
        if active_button(JOYPAD.RIGHT) then
            ok_action = self.selection:increment()
        elseif active_button(JOYPAD.LEFT) then
            ok_action = self.selection:decrement()
        end
        self.value_change(self.selection:get_value())
    end
    
    if self.on_select then
        if joysticks.is_pressed_any(JOYPAD.B) then
            ok_action = true
            self.on_select(ctx)
        end
    end

    return ok_action
end

function MenuChoiceImpl:draw(font: MenuFont)
    local line = MenuLine.new({MenuLineColumn.new(self.menu_text, const.MAP_WIDTH)}, self.y_pos)
    if self.selection then
        line = MenuLine.new({
            MenuLineColumn.new("", 20),
            MenuLineColumn.new(self.menu_text, 170),
            MenuLineColumn.new("-", 30),
            MenuLineColumn.new(self.selection:as_menu_string(), 50),
            MenuLineColumn.new("", 50),
        }, self.y_pos)
    end

    local x_pos = 0.0
    for _, column in ipairs(line.columns) do
        font:print_centered(column.text, column.width, points.new(x_pos, self.y_pos))
        x_pos = x_pos + column.width
    end
end

function choices.new_integer(menu_text: string, y_pos: integer, selection: MenuSelection<integer>, callback: function(integer)): MenuChoiceImpl<integer>
    local self: MenuChoiceImpl<integer> = setmetatable({}, { __index = MenuChoiceImpl })
    self.y_pos = y_pos
    self.selection = selection
    self.menu_text = menu_text
    self.value_change = callback
    return self
end

function choices.new_number(menu_text: string, y_pos: integer, selection: MenuSelection<number>, callback: function(number)): MenuChoiceImpl<number>
    local self: MenuChoiceImpl<number> = setmetatable({}, { __index = MenuChoiceImpl })
    self.y_pos = y_pos
    self.selection = selection
    self.menu_text = menu_text
    self.value_change = callback
    return self
end

function choices.new_enum<T>(menu_text: string, y_pos: integer, selection: MenuSelection<T>, callback: function(T)): MenuChoiceImpl<T>
    local self: MenuChoiceImpl<T> = setmetatable({}, { __index = MenuChoiceImpl })
    self.y_pos = y_pos
    self.selection = selection
    self.menu_text = menu_text
    self.value_change = callback
    return self
end

function choices.new_done(menu_text: string, y_pos: integer, callback: function(ctx: Scene)): MenuChoiceImpl<boolean>
    local self: MenuChoiceImpl<boolean> = setmetatable({}, { __index = MenuChoiceImpl })
    self.y_pos = y_pos
    self.menu_text = menu_text
    self.value_change = function(_: boolean) end
    self.on_select = callback
    return self
end

return choices
