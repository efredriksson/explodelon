local logger = require("engine.logger")
local rectangles = require("engine.geometry.rectangles")
local settings = require("engine.settings")

local type Entity = require("engine.entity")
local type Rectangle = rectangles.Rectangle

local LIMIT_Y_TILES = 100

local function index_2d_to_1d(i: integer, j: integer): integer
    return i * LIMIT_Y_TILES + j
end

local function get_indexes(hitbox: Rectangle): function(): integer
    local block_size = settings.block_size
    local x_min, y_min = math.ceil(hitbox.x / block_size), math.ceil(hitbox.y / block_size)
    local x_max, y_max = math.ceil((hitbox.x + hitbox.width) / block_size), math.ceil((hitbox.y + hitbox.height) / block_size)

    if y_max >= LIMIT_Y_TILES then
        logger.warning("Tile out of bound, collision checking will not work")
    end

    local i, j = x_min, y_min
    return function(): integer
        if i > x_max then return nil end
        local index = index_2d_to_1d(i, j)
        j = j + 1
        if j > y_max then
            j = y_min
            i = i + 1
        end
        return index
    end
end

local record Group<T>
    set: {T: T}
end

local record Lookup
    map: {integer: {Entity}}
end

local collision = {Group = Group, Lookup = Lookup}

function Group:get(object: any): T | nil
    return self.set[object as T]
end

function Group:list(): {T}
    local list: {T} = {}
    for _, entity in pairs(self.set) do
        table.insert(list, entity)
    end

    return list
end

function collision.new_group<T>(...: {T}): Group<T>
    local self: Group<T> = setmetatable({}, { __index = Group })

    self.set = {}
    for _, entity_list in ipairs({...}) do
        for _, entity in ipairs(entity_list) do
            self.set[entity] = entity
        end
    end
    return self
end

function collision.new_lookup(...: {Entity}): Lookup
    local self: Lookup = setmetatable({}, { __index = Lookup })
    self.map = {}

    for _, entity_list in ipairs({...}) do
        for _, entity in ipairs(entity_list) do
            for index in get_indexes(entity:hitbox()) do
                if not self.map[index] then
                    self.map[index] = {}
                end
                table.insert(self.map[index], entity)
            end
        end
    end
    return self
end

function Lookup:collisions_between<K is Entity,T>(entities: {K}, group: Group<T>): {K: T}
    local collides_with: {K: T} = {}
    for _, entity in ipairs(entities) do
        for index in get_indexes(entity:hitbox()) do
            for _, check_against in ipairs(self.map[index] or {}) do
                if entity ~= check_against and entity:hitbox():overlap(check_against:hitbox()) then
                    local in_group = group:get(check_against)
                    if not in_group is nil then
                        collides_with[entity] = in_group
                    end
                end
            end
        end
    end

    return collides_with
end

function Lookup:in_box_and_group<T>(box: Rectangle, group: Group<T>): {T}
    local in_box_for_group: {T} = {}
    for index in get_indexes(box) do
        for _, check_against in ipairs(self.map[index] or {}) do
            if box:overlap(check_against:hitbox()) then
                local in_group = group:get(check_against)
                if in_group then
                    table.insert(in_box_for_group, in_group)
                end
            end
        end
    end

    return in_box_for_group
end

return collision
