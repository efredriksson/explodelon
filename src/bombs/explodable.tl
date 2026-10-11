local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local type Explodable = interface
    --- How something standing in the way of a flame takes it.
    enum MeetsFlame
        "blocks" -- the flame ends before its tile and leaves it untouched
        "ignites" -- the flame ends before its tile and blows it up
        "engulfed" -- the flame covers its tile and ends there
    end

    get_position: function(self): Point
    meets_flame: MeetsFlame
    blow_up: function(self, hit_fraction: number)
    hitbox: function(self): Rectangle
end

return Explodable
