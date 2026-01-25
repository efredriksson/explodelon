require("engine.geometry.points")
require("engine.geometry.rectangles")


global type Entity = interface
    get_position: function(self): Point
    draw: function(self)
    hitbox: function(self): Rectangle
    clear: function(self)
end
