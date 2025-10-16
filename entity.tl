require("geometry")

global type Entity = interface
    position: Point
    draw: function(self)
end

global type ExplosionBlocking = interface
    position: Point
    in_explosion: boolean
    blow_up: function(self)
end

global type Explodable = interface
    position: Point
    blow_up: function(self)
end
