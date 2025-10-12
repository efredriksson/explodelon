require("geometry")

global type Entity = interface
    position: Point
    draw: function(self)
end

global type ExplodeTarget = interface
    position: Point
    blow_up: function(self)
end
