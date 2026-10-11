local record Vector
    x: number
    y: number
end

local type Direction = enum
    "up"
    "down"
    "right"
    "left"
end

local vectors = {Vector = Vector, Direction = Direction}

function vectors.new(x: number, y: number): Vector
    local self: Vector = setmetatable({}, {__index = Vector})
    self.x = x or 0
    self.y = y or 0
    return self
end

local UNIT <total>: {Direction: Vector} = {
    up = vectors.new(0, -1),
    down = vectors.new(0, 1),
    right = vectors.new(1, 0),
    left = vectors.new(-1, 0),
}

function vectors.from_direction(direction: Direction): Vector
    return UNIT[direction]
end

local OPPOSITE: {Direction: Direction} = {
    up = "down",
    down = "up",
    left = "right",
    right = "left",
}

function vectors.opposite(direction: Direction): Direction
    return OPPOSITE[direction]
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

function Vector:dot_product(other: Vector): number
    return self.x * other.x + self.y * other.y
end

function Vector:orthogonal(other: Vector): boolean
    return self:dot_product(other) == 0
end

return vectors
