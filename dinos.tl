require("geometry")

global type DinoType = enum
    "blue"
end

global type DinoAction = enum
    "walk"
    "idle"
    "dying"
end

global record Dino
    position: Point
    direction: Direction
    action: DinoAction
    color: DinoType
    level: integer
end

function Dino.new(position: Point, direction: Direction): Dino
   local self: Dino = setmetatable({}, { __index = Dino })
   self.position = position
   self.direction = direction
   self.action = "idle"
   self.color = "blue"
   self.level = 1
   return self
end

function Dino:level_up()
    self.level = math.min(self.level + 1, 3)
end
