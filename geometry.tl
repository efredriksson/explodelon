global record Point
   x: number
   y: number
end

global record Vector
   x: number
   y: number
end

global record Rectangle
	x: number
	y: number
	width: number
	height: number
end

global type Direction = enum
   "up"
   "down"
   "right"
   "left"
end

function Point.new(x: number, y: number): Point
   local self: Point = setmetatable({}, { __index = Point })
   self.x = x or 0
   self.y = y or 0
   return self
end

function Point:move(delta: Vector): Point
   return Point.new(self.x + delta.x, self.y + delta.y)
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

function Vector.new(x: number, y: number): Vector
   local self: Vector = setmetatable({}, { __index = Vector })
   self.x = x or 0
   self.y = y or 0
   return self
end

function Vector:permutate_if(condition: boolean): Vector
   if condition then
      return Vector.new(self.y, self.x)
   end

   return self
end

function Vector:scale(val: number): Vector
   return Vector.new(self.x * val, self.y * val)
end

function Vector:minus(other: Vector): Vector
   return Vector.new(self.x - other.x, self.y - other.y)
end

function Rectangle.new(x: number, y: number, width: number, height: number): Rectangle
   local self: Rectangle = setmetatable({}, { __index = Rectangle })
   self.x = x or 0
   self.y = y or 0
   self.width = width or 0
   self.height = height or 0
   return self
end

local function interval_overlap(xmin1: number, xmax1: number, xmin2: number, xmax2: number): boolean
	return xmax1 > xmin2 and xmax2 > xmin1
end

function Rectangle:overlap(other: Rectangle): boolean
    return interval_overlap(self.x, self.x + self.width, other.x, other.x + other.width) and
		interval_overlap(self.y, self.y + self.height, other.y, other.y + other.height)
end

local function interval_contained(xmin1: number, xmax1: number, xmin2: number, xmax2: number): boolean
	return xmin1 >= xmin2 and xmax1 <= xmax2
end

function Rectangle:contains(other: Rectangle): boolean
   return interval_contained(other.x, other.x + other.width, self.x, self.x + self.width) and
		interval_contained(other.y, other.y + other.height, self.y, self.y + self.height)
end

--- Clamp a number in interval [min, max]
local function clamp(val: number, min: number, max: number): number
	return math.min(math.max(val, min), max)
end

function Rectangle:clamp(rec: Rectangle): Rectangle
   return Rectangle.new(
      clamp(rec.x, self.x, self.x + self.width - rec.width),
      clamp(rec.y, self.y, self.y + self.height - rec.height),
      rec.width,
      rec.height
   )
end

function Rectangle:center(): Point
   return Point.new(
      self.x + self.width / 2,
      self.y + self.height / 2
   )
end

--- Distance between rectangles from their centers
function Rectangle:center_distance(other: Rectangle): number
   return self:center():distance_to(other:center())
end

function Rectangle:top_left(): Point
   return Point.new(self.x, self.y)
end

function Rectangle:shrink(shrink: number): Rectangle
   return Rectangle.new(
      self.x + shrink,
      self.y + shrink,
      self.width - 2 * shrink,
      self.height - 2 * shrink
   )
end