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

global record MenuSelection
   value: integer
   min: integer
   max: integer
end

function MenuSelection.new(start: integer, min: integer, max: integer): MenuSelection
   local self: MenuSelection = setmetatable({}, { __index = MenuSelection })
   self.value = start
   self.min = min or 0
   self.max = max or 100
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

global function get_ok_sound(): Source
    return lutro.audio.newSource("assets/menu_good.wav", "static")
end
