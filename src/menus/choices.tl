require("fonts")
require("engine.scenes")
local points = require("engine.geometry.points")
local joysticks = require("engine.joysticks")
local items = require("menus.items")
local screen = require("screen")


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

function MenuChoiceImpl:update(_: Scene): boolean
    local ok_action = false

    local function active_button(button: integer): boolean
        local time_until_fast_change = 0.3
        return joysticks.is_pressed_any(button) or
            joysticks.is_down_for_any(button, time_until_fast_change)
    end

    if active_button(joysticks.BUTTONS.RIGHT) then
        ok_action = self.selection:increment()
    elseif active_button(joysticks.BUTTONS.LEFT) then
        ok_action = self.selection:decrement()
    end
    self.value_change(self.selection:get_value())

    return ok_action
end

function MenuChoiceImpl:draw(font: MenuFont)
    local line = MenuLine.new({
        MenuLineColumn.new("", 20),
        MenuLineColumn.new(self.menu_text, 170),
        MenuLineColumn.new("-", 30),
        MenuLineColumn.new(self.selection:as_menu_string(), 50),
        MenuLineColumn.new("", 50),
    }, self.y_pos)

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

local record MenuAction is MenuChoice
    y_pos: integer
    menu_text: string
    on_select: function(ctx: Scene)
end

function MenuAction:update(ctx: Scene): boolean
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        self.on_select(ctx)
        return true
    end

    return false
end

function MenuAction:draw(font: MenuFont)
    font:print_centered(self.menu_text, screen.WIDTH, points.new(0, self.y_pos))
end

function choices.new_done(menu_text: string, y_pos: integer, callback: function(ctx: Scene)): MenuAction
    local self: MenuAction = setmetatable({}, { __index = MenuAction })
    self.y_pos = y_pos
    self.menu_text = menu_text
    self.on_select = callback
    return self
end

return choices
