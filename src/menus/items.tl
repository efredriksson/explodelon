local audio = require("engine.audio")
local clock_text = require("clock_text")


global record MenuLineColumn
    text: string
    width: number
end

function MenuLineColumn.new(text: string, width: number): MenuLineColumn
    local self: MenuLineColumn = setmetatable({}, { __index = MenuLineColumn })
    self.text = text
    self.width = width
    return self
end

global record MenuLine
    columns: {MenuLineColumn}
    y_pos: number
end

function MenuLine.new(columns: {MenuLineColumn}, y_pos: number): MenuLine
    local self: MenuLine = setmetatable({}, { __index = MenuLine })
    self.columns = columns
    self.y_pos = y_pos
    return self
end

global record MenuSelection<T>
    value: integer
    min: integer
    max: integer
    tostring: function(integer): string
    convert: function(integer): T
end

local menu_items = {}

function menu_items.new_integer_selection(start: integer, min: integer, max: integer): MenuSelection<integer>
    local self: MenuSelection<integer> = setmetatable({}, { __index = MenuSelection })
    self.value = start
    self.min = min or 0
    self.max = max or 100
    self.tostring = tostring
    self.convert = function(v: integer): integer return v end
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

function MenuSelection:reduce_max_val()
    self.max = self.max - 1
    self.value = math.min(self.value, self.max)
end

function MenuSelection:get_value(): T
    return self.convert(self.value)
end

function MenuSelection:as_menu_string(): string
    return self.tostring(self.value)
end

function menu_items.new_boolean_selection(on_by_default: boolean): MenuSelection<boolean>
    local function value_as_on_off(value: integer): string
        if value == 1 then
            return 'on'
        else
            return 'off'
        end
    end
    local start_val = on_by_default and 1 or 2
    local self: MenuSelection<boolean> = setmetatable({}, { __index = MenuSelection })
    self.value = start_val
    self.min = 1
    self.max = 2
    self.tostring = value_as_on_off
    self.convert = function(v: integer): boolean return v == 1 end
    return self
end

function menu_items.new_enum<T>(choices: {T}): MenuSelection<T>
    local function value_as_enum(value: integer): string
        return tostring(choices[value])
    end
    local self: MenuSelection<T> = setmetatable({}, { __index = MenuSelection })
    self.value = 1
    self.min = 1
    self.max = #choices
    self.tostring = value_as_enum
    self.convert = function(v: integer): T return choices[v] end
    return self
end

function menu_items.new_time_selection(start_idx: integer, times: {number}): MenuSelection<number>
    local function value_as_clock_time(index: integer): string
        local time = times[index]
        return clock_text.from_time(time)
    end
    local self: MenuSelection<number> = setmetatable({}, { __index = MenuSelection })
    self.value = start_idx
    self.min = 1
    self.max = #times
    self.tostring = value_as_clock_time
    self.convert = function(i: integer): number return times[i] end
    return self
end

function menu_items.new_number_selection(start_idx: integer, choices: {number}): MenuSelection<number>
    local function value_as_string(index: integer): string
        local val = choices[index]
        return tostring(val)
    end
    local self: MenuSelection<number> = setmetatable({}, { __index = MenuSelection })
    self.value = start_idx
    self.min = 1
    self.max = #choices
    self.tostring = value_as_string
    self.convert = function(i: integer): number return choices[i] end
    return self
end

function menu_items.ok_sound(): Source
    return audio.new_source("assets/menu_good.wav", "static")
end

return menu_items
