local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local type Kinematic = interface
    get_position: function(self): Point
    hit_with_bomb: function(self)
    hitbox: function(self): Rectangle
    movementbox: function(self): Rectangle
end

return Kinematic
