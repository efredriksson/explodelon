global record Vector
   x: number
   y: number
end

global type Direction = enum
   "up"
   "down"
   "right"
   "left"
end

local vectors = {}


function vectors.new(x: number, y: number): Vector
   local self: Vector = setmetatable({}, { __index = Vector })
   self.x = x or 0
   self.y = y or 0
   return self
end

function vectors.from_direction(direction: Direction): Vector
   if direction == "up" then
		return vectors.new(0, -1)
	elseif direction == "down" then
		return vectors.new(0, 1)
	elseif direction == "right" then
		return vectors.new(1, 0)
	elseif direction == "left" then
		return vectors.new(-1, 0)
	else
		assert(false, "bad direction")
	end
end

function Vector:permutate_if(condition: boolean): Vector
   if condition then
      return vectors.new(self.y, self.x)
   end

   return self
end

function Vector:scale(val: number): Vector
   return vectors.new(self.x * val, self.y * val)
end

function Vector:abs(): Vector
   return vectors.new(math.abs(self.x), math.abs(self.y))
end

function Vector:length(): number
   return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

function Vector:normalize(): Vector
   return self:scale(1 / self:length())
end

function Vector:minus(other: Vector): Vector
   return vectors.new(self.x - other.x, self.y - other.y)
end

function Vector:plus(other: Vector): Vector
   return vectors.new(self.x + other.x, self.y + other.y)
end

function Vector:same_direction(other: Vector): boolean
   local function same_sign(x: number, y: number): boolean
      return x == y or x * y > 0
   end

   return same_sign(self.x, other.x) and same_sign(self.y, other.y)
end

function Vector:dot_product(other: Vector): number
   return self.x * other.x + self.y * other.y
end

function Vector:orthogonal(other: Vector): boolean
   return self:dot_product(other) == 0
end

return vectors
