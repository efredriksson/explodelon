local logger = require("engine.logger")
local rectangles = require("engine.geometry.rectangles")
local settings = require("engine.settings")

local type Entity = require("engine.entity")
local type Rectangle = rectangles.Rectangle

local LIMIT_Y_TILES = 100

local function index_2d_to_1d(i: integer, j: integer): integer
    return i * LIMIT_Y_TILES + j
end

local function get_indexes(hitbox: Rectangle): (integer, integer, integer, integer)
    local block_size = settings.block_size
    local x_min, y_min = math.ceil(hitbox.x / block_size), math.ceil(hitbox.y / block_size)
    local x_max, y_max = math.ceil((hitbox.x + hitbox.width) / block_size), math.ceil((hitbox.y + hitbox.height) / block_size)

    if y_max >= LIMIT_Y_TILES then
        logger.warning("Tile out of bound, collision checking will not work")
    end

    return x_min, x_max, y_min, y_max
end

local interface ReadableGroup<T>
    get: function(self, any): T | nil
    is_empty: function(self): boolean
end

local record Group<T> is ReadableGroup<T>
    set: {any: T}
end

local record Lookup
    map: {integer: {Entity}}
end

local record CombinedGroup<T> is ReadableGroup<T>
    sub_groups: {ReadableGroup<T>}
end

local collision = {Group = Group, Lookup = Lookup, CombinedGroup = CombinedGroup, ReadableGroup = ReadableGroup}

function Group:get(object: any): T | nil
    return self.set[object]
end

function Group:list(): {T}
    local list: {T} = {}
    for _, entity in pairs(self.set) do
        table.insert(list, entity)
    end

    return list
end

function Group:is_empty(): boolean
    return next(self.set) == nil
end

function CombinedGroup:get(object: any): T | nil
    for _, sub_group in ipairs(self.sub_groups) do
        local found = sub_group:get(object)
        if found then
            return found
        end
    end
    return nil
end

function CombinedGroup:is_empty(): boolean
    for _, sub_group in ipairs(self.sub_groups) do
        if not sub_group:is_empty() then
            return false
        end
    end
    return true
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

function collision.new_group_from_set<T>(set: {any: T}): Group<T>
    local self: Group<T> = setmetatable({}, { __index = Group })

    self.set = set
    return self
end

function collision.new_combined_group<T>(...: {any: T}): CombinedGroup<T>
    local self: CombinedGroup<T> = setmetatable({}, { __index = CombinedGroup })

    self.sub_groups = {}
    for _, set in ipairs({...}) do
        table.insert(self.sub_groups, collision.new_group_from_set(set))
    end
    return self
end

function collision.new_lookup(...: {Entity}): Lookup
    local self: Lookup = setmetatable({}, { __index = Lookup })
    self.map = {}

    for _, entity_list in ipairs({...}) do
        for _, entity in ipairs(entity_list) do
            local x_min, x_max, y_min, y_max = get_indexes(entity:hitbox())
            for i = x_min, x_max do
                for j = y_min, y_max do
                    local index = index_2d_to_1d(i, j)
                    if not self.map[index] then
                        self.map[index] = {}
                    end
                    table.insert(self.map[index], entity)
                end
            end
        end
    end
    return self
end

function Lookup:collisions_between<K is Entity,T>(entities: {K}, group: ReadableGroup<T>): {K: T}
    local collides_with: {K: T} = {}
    if group:is_empty() then
        return collides_with
    end

    for _, entity in ipairs(entities) do
       local x_min, x_max, y_min, y_max = get_indexes(entity:hitbox())
        for i = x_min, x_max do
            for j = y_min, y_max do
                local index = index_2d_to_1d(i, j)
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
    end

    return collides_with
end

function Lookup:in_box_and_group<T>(box: Rectangle, group: ReadableGroup<T>): {T}
    local in_box_for_group: {T} = {}
    if group:is_empty() then
        return in_box_for_group
    end

    local x_min, x_max, y_min, y_max = get_indexes(box)
    for i = x_min, x_max do
        for j = y_min, y_max do
            local index = index_2d_to_1d(i, j)
            for _, check_against in ipairs(self.map[index] or {}) do
                if box:overlap(check_against:hitbox()) then
                    local in_group = group:get(check_against)
                    if in_group then
                        table.insert(in_box_for_group, in_group)
                    end
                end
            end
        end
    end

    return in_box_for_group
end

return collision
