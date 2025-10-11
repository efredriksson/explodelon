global record MenuSelection
   value: integer
   min: integer
   max: integer
end

global record MenuButton
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

global function get_ok_sound(): Source
    return lutro.audio.newSource("assets/menu_good.wav", "static")
end
