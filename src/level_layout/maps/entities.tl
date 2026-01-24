local hitboxes = require("hitboxes")


global record Goal
    position: Point
    pair: Point
end

function Goal.new(position: Point, pair: Point): Goal
    local self: Goal = setmetatable({}, { __index = Goal })
    self.position = position
    self.pair = pair
    return self
end

function Goal:get_hitbox(): Rectangle
    return hitboxes.new_block(self.position)
end

global record ConveyorBelt
    position: Point
    direction: Vector
end

function ConveyorBelt.new(position: Point, direction: Vector): ConveyorBelt
    local self: ConveyorBelt = setmetatable({}, { __index = ConveyorBelt })
    self.position = position
    self.direction = direction
    return self
end

function ConveyorBelt:get_hitbox(): Rectangle
    return hitboxes.new_block(self.position)
end

global type MapLayout = interface
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
end
