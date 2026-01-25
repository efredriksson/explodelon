local vectors = require("engine.geometry.vectors")

local type Vector = vectors.Vector

local record Point
   x: number
   y: number
   metamethod __tostring: function(Point): string
end

local points = {Point = Point}

local function point_to_string(p: Point): string
   return tostring(p.x) .. ":" .. tostring(p.y)
end

function points.new(x: number, y: number): Point
   local self: Point = setmetatable({}, { __index = Point, __tostring = point_to_string })
   self.x = x or 0
   self.y = y or 0
   return self
end

function Point:move(delta: Vector): Point
   return points.new(self.x + delta.x, self.y + delta.y)
end

function Point:distance_to(other: Point): number
   return math.sqrt((other.x - self.x) ^ 2 + (other.y - self.y) ^ 2) 
end

function Point:in_radius_of(other: Point, radius: number): boolean
   return self:distance_to(other) < radius 
end

function Point:equal(other: Point): boolean
   return self.x == other.x and self.y == other.y 
end

return points
