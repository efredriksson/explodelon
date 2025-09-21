require("geometry")

global type Entity = interface
    position: Point
    draw: function(self)
end
