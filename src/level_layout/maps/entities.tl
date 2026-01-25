local hitboxes = require("engine.hitboxes")
local vectors = require("engine.geometry.vectors")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Vector = vectors.Vector
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local record Goal
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

local record ConveyorBelt
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

local type MapLayout = interface
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
end

local entities = {
    Goal = Goal,
    ConveyorBelt = ConveyorBelt,
    MapLayout = MapLayout,
}

return entities
