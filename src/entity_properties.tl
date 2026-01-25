require("engine.geometry.points")
require("engine.geometry.rectangles")


global type Explodable = interface
    get_position: function(self): Point
    in_explosion: boolean
    blow_up: function(self)
    hitbox: function(self): Rectangle
end

global type Kinematic = interface
    get_position: function(self): Point
    hit_with_bomb: function(self)
    hitbox: function(self): Rectangle
    movementbox: function(self): Rectangle
end
