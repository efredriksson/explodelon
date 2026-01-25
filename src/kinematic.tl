require("engine.geometry.points")
require("engine.geometry.rectangles")


global type Kinematic = interface
    get_position: function(self): Point
    hit_with_bomb: function(self)
    hitbox: function(self): Rectangle
    movementbox: function(self): Rectangle
end
