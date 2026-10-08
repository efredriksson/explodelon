-- A stand-in for the lutro engine so game code runs under busted: every call is
-- accepted and returns another stand-in, except image sizes (read from the real
-- PNG headers, since layout code depends on them) and randomness (seeded Lua).
local stand_in = {}
local function new_stand_in() return setmetatable({}, stand_in) end
stand_in.__index = function(table_, key)
    local value = new_stand_in()
    rawset(table_, key, value)
    return value
end
stand_in.__call = new_stand_in

local function png_size(path)
    local file = type(path) == "string" and io.open(path, "rb")
    if not file then
        return 16, 16
    end
    local header = file:read(24)
    file:close()
    local function big_endian(at)
        local a, b, c, d = header:byte(at, at + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    return big_endian(17), big_endian(21)
end

local function new_image(path)
    local width, height = png_size(path)
    local image = new_stand_in()
    rawset(image, "getWidth", function() return width end)
    rawset(image, "getHeight", function() return height end)
    rawset(image, "getDimensions", function() return width, height end)
    rawset(image, "getData", function()
        return {getPixel = function() return 0, 0, 0, 0 end, setPixel = function() end}
    end)
    return image
end

return function(seed)
    math.randomseed(seed)
    lutro = new_stand_in()
    lutro.math.random = function(low, high)
        if low == nil then
            return math.random()
        elseif high == nil then
            return math.random(low)
        end
        return math.random(low, high)
    end
    lutro.joystick.isDown = function() return false end
    lutro.graphics.newImage = new_image
end
