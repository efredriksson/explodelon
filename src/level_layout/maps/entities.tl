local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local hitboxes = require("engine.hitboxes")

local type Vector = vectors.Vector
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local record Goal
    position: Point
    pair: Point
end

function Goal.new(position: Point, pair: Point): Goal
    local self: Goal = setmetatable({}, {__index = Goal})
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
    local self: ConveyorBelt = setmetatable({}, {__index = ConveyorBelt})
    self.position = position
    self.direction = direction
    return self
end

function ConveyorBelt:get_hitbox(): Rectangle
    return hitboxes.new_block(self.position)
end

local record Trampoline
    position: Point
end

function Trampoline.new(position: Point): Trampoline
    local self: Trampoline = setmetatable({}, {__index = Trampoline})
    self.position = position
    return self
end

function Trampoline:get_hitbox(): Rectangle
    return hitboxes.new_block(self.position)
end

local enum BlockType
    "none"
    "hard"
    "hard_tall"
    "soft"
end

local type MapLayout = interface
    get_conveyor_belts: function(self): {ConveyorBelt}
    get_goals: function(self): {Goal}
    get_trampolines: function(self): {Trampoline}
    get_block_layout: function(self, occupies: {Point}): {integer: {integer: BlockType}}
    has_ice: function(self): boolean
end

local entities = {
    Goal = Goal,
    ConveyorBelt = ConveyorBelt,
    Trampoline = Trampoline,
    MapLayout = MapLayout,
    BlockType = BlockType,
}

return entities
