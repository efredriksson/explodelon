global record Point
   x: number
   y: number
end

global record Rectangle
	x: number
	y: number
	width: number
	height: number
end

function Point.new(x: number, y: number): Point
   local self: Point = setmetatable({}, { __index = Point })
   self.x = x or 0
   self.y = y or 0
   return self
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
	return xmax1 >= xmin2 and xmax2 >= xmin1
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