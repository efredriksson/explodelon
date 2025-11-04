local points = require("geometry.points")

global record Rectangle
	x: number
	y: number
	width: number
	height: number
end

local rectangles = {}

function rectangles.new(x: number, y: number, width: number, height: number): Rectangle
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
   return rectangles.new(
      clamp(rec.x, self.x, self.x + self.width - rec.width),
      clamp(rec.y, self.y, self.y + self.height - rec.height),
      rec.width,
      rec.height
   )
end

function Rectangle:center(): Point
   return points.new(
      self.x + self.width / 2,
      self.y + self.height / 2
   )
end

--- Distance between rectangles from their centers
function Rectangle:center_distance(other: Rectangle): number
   return self:center():distance_to(other:center())
end

function Rectangle:top_left(): Point
   return points.new(self.x, self.y)
end

function Rectangle:shrink(shrink: number): Rectangle
   return rectangles.new(
      self.x + shrink,
      self.y + shrink,
      self.width - 2 * shrink,
      self.height - 2 * shrink
   )
end

function Rectangle:shift(movement: Vector): Rectangle
   local new_top_left = self:top_left():move(movement)
   return rectangles.new(
      new_top_left.x,
      new_top_left.y,
      self.width,
      self.height
   )
end

return rectangles
