require("geometry.points")
require("geometry.vectors")
local hitboxes = require("hitboxes")


global type DinoColor = enum
    "blue"
    "pink"
    "purple"
    "green"
    "yellow"
end

global type DinoAction = enum
    "walk"
    "idle"
    "dying"
    "stunned"
end

global record Dino
    position: Point
    direction: Direction
    action: DinoAction
    color: DinoColor
    level: integer
    hatching: boolean
end

local DINO_COLORS: {DinoColor} = {"blue", "pink", "purple", "green", "yellow"}

local dinos = {}

function dinos.new(position: Point, direction: Direction): Dino
   local self: Dino = setmetatable({}, { __index = Dino })
   self.position = position
   self.direction = direction
   self.action = "idle"
   self.color = DINO_COLORS[lutro.math.random(#DINO_COLORS)]
   self.level = 1
   self.hatching = true
   return self
end

function Dino:level_up()
    self.level = math.min(self.level + 1, 3)
end

function Dino:hitbox(): Rectangle
    local padding = 4
    return hitboxes.new_block(self.position, padding)
end

return dinos
