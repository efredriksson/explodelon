local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local type Explodable = interface
    get_position: function(self): Point
    in_explosion: boolean
    blow_up: function(self)
    hitbox: function(self): Rectangle
end

return Explodable
