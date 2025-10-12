require("geometry")

global type Entity = interface
    position: Point
    draw: function(self)
end

global type BlocksExplosion = interface
    position: Point
    animate_explosion: boolean
end

global type ExplodeTarget = interface
    position: Point
    blow_up: function(self)
end
