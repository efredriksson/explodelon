require("fonts")
require("scenes")
local const = require("const")
local points = require("geometry.points")
local joysticks = require("joysticks")
local items = require("menus.items")


local JOYPAD = joysticks.buttons()
local choices = {}

global type MenuChoice = interface
    update: function(self): boolean
    draw: function(self, font: MenuFont)
end

local record BooleanMenuChoice is MenuChoice
    selection: MenuSelection
    y_pos: integer
    menu_text: string
    callback: function(boolean)
end

function choices.new_boolean(menu_text: string, y_pos: integer, on_by_default: boolean, callback: function(boolean)): BooleanMenuChoice
    local start_val = on_by_default and 1 or 2
    local selection = items.new_selection(start_val, 1, 2)

    local self: BooleanMenuChoice = setmetatable({}, { __index = BooleanMenuChoice })
    self.y_pos = y_pos
    self.selection = selection
    self.menu_text = menu_text
    self.callback = callback
    return self
end

function BooleanMenuChoice:update(): boolean
    local ok_action = false
    if joysticks.is_pressed(1, JOYPAD.RIGHT) then
        ok_action = self.selection:increment()
    elseif joysticks.is_pressed(1, JOYPAD.LEFT) then
        ok_action = self.selection:decrement()
    end

    self.callback(self.selection.value == 1)
    return ok_action
end

function BooleanMenuChoice:draw(font: MenuFont)
    local function value_as_on_off(value: integer): string
        if value == 1 then
            return 'on'
        else
            return 'off'
        end
    end

    local line = MenuLine.new({
        MenuLineColumn.new("", 20),
        MenuLineColumn.new(self.menu_text, 170),
        MenuLineColumn.new("-", 30),
        MenuLineColumn.new(value_as_on_off(self.selection.value), 50),
        MenuLineColumn.new("", 50),
    }, self.y_pos)

    local x_pos = 0.0
    for _, column in ipairs(line.columns) do
        font:print_centered(column.text, column.width, points.new(x_pos, self.y_pos))
        x_pos = x_pos + column.width
    end
end

local record IntegerMenuChoice is MenuChoice
    selection: MenuSelection
    y_pos: integer
    menu_text: string
    callback: function(integer)
end


function choices.new_integer(menu_text: string, y_pos: integer, selection: MenuSelection, callback: function(integer)): IntegerMenuChoice
    local self: IntegerMenuChoice = setmetatable({}, { __index = IntegerMenuChoice })
    self.y_pos = y_pos
    self.selection = selection
    self.menu_text = menu_text
    self.callback = callback
    return self
end

function IntegerMenuChoice:update(): boolean
    local ok_action = false
    
    if joysticks.is_pressed(1, JOYPAD.RIGHT) then
        ok_action = self.selection:increment()
    elseif joysticks.is_pressed(1, JOYPAD.LEFT) then
        ok_action = self.selection:decrement()
    end

    self.callback(self.selection.value)
    return ok_action
end

function IntegerMenuChoice:draw(font: MenuFont)
    local line = MenuLine.new({
      MenuLineColumn.new("", 20),
      MenuLineColumn.new(self.menu_text, 170),
      MenuLineColumn.new("-", 30),
      MenuLineColumn.new(tostring(self.selection.value), 50),
      MenuLineColumn.new("", 50),
   }, self.y_pos)

    local x_pos = 0.0
    for _, column in ipairs(line.columns) do
        font:print_centered(column.text, column.width, points.new(x_pos, self.y_pos))
        x_pos = x_pos + column.width
    end
end

local record MenuDoneChoice is MenuChoice
    y_pos: integer
    menu_text: string
    callback: function()
end

function choices.new_done(menu_text: string, y_pos: integer, callback: function()): MenuDoneChoice
    local self: MenuDoneChoice = setmetatable({}, { __index = MenuDoneChoice })
    self.y_pos = y_pos
    self.menu_text = menu_text
    self.callback = callback
    return self
end

function MenuDoneChoice:update(): boolean
    local done = joysticks.is_pressed(1, JOYPAD.B)
    if done then
        self.callback()
    end

    return done
end

function MenuDoneChoice:draw(font: MenuFont)
    local line = MenuLine.new({MenuLineColumn.new(self.menu_text, const.MAP_WIDTH)}, self.y_pos)

    local x_pos = 0.0
    for _, column in ipairs(line.columns) do
        font:print_centered(column.text, column.width, points.new(x_pos, self.y_pos))
        x_pos = x_pos + column.width
    end
end

return choices
