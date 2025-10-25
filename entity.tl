require("geometry")

global type Entity = interface
    get_position: function(self): Point
    draw: function(self)
end

global type ExplosionBlocking = interface
    get_position: function(self): Point
    in_explosion: boolean
    blow_up: function(self)
end

global type Explodable = interface
    get_position: function(self): Point
    blow_up: function(self)
end
