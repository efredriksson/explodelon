local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local type Entity = interface
    get_position: function(self): Point
    z_index: integer
    draw: function(self)
    hitbox: function(self): Rectangle
    clear: function(self)
end

return Entity
