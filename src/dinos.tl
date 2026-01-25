require("engine.geometry.points")
require("engine.geometry.vectors")
local hitboxes = require("engine.hitboxes")
local settings = require("settings")

global type DinoAction = enum
    "walk"
    "idle"
    "dying"
    "stunned"
    "jump"
    "dash"
    "crashed"
    "slide"
end

global record Dino
    position: Point
    direction: Direction
    action: DinoAction
    color: DinoColor
    level: integer
    hatching: boolean
    jump_powerup_for: number
    throw_powerup_for: number
end

local dinos = {}

function dinos.new(position: Point, direction: Direction): Dino
   local self: Dino = setmetatable({}, { __index = Dino })
   self.position = position
   self.direction = direction
   self.action = "idle"
   local dino_choices = settings.get_enabled_dinos()
   self.color = dino_choices[lutro.math.random(#dino_choices)]
   self.level = 1
   self.hatching = true
   self.jump_powerup_for = 0
   self.throw_powerup_for = 0
   return self
end

function Dino:level_up()
    self.level = math.min(self.level + 1, 3)
end

function Dino:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(4)
end

return dinos
