-- The board a preview plays on. Nothing about who moves; that is a Choreography.

local points = require("engine.geometry.points")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local settings = require("settings")

local type ItemType = settings.ItemType
local type Map = settings.Map
local type Point = points.Point
local type SoftBlockConfig = map_entities.SoftBlockConfig

local record ItemDrop
    at: Point
    kind: ItemType
end

function ItemDrop.new(at: Point, kind: ItemType): ItemDrop
    local self: ItemDrop = setmetatable({}, {__index = ItemDrop})
    self.at = at
    self.kind = kind
    return self
end

local record StaticBomb
    position: Point
    fire: integer
end

function StaticBomb.new(position: Point, fire: integer): StaticBomb
    local self: StaticBomb = setmetatable({}, {__index = StaticBomb})
    self.position = position
    self.fire = fire
    return self
end

local record Scenery
    map: Map
    soft_blocks: {SoftBlockConfig}
    items: {ItemDrop}
    eggs: {Point}
    bombs: {StaticBomb}
end

local scenery = {
    ItemDrop = ItemDrop,
    StaticBomb = StaticBomb,
    Scenery = Scenery,
}

function scenery.new(
    map: Map,
    soft_blocks: {SoftBlockConfig},
    items: {ItemDrop},
    eggs?: {Point},
    bombs?: {StaticBomb}
): Scenery
    local self: Scenery = setmetatable({}, {__index = Scenery})
    self.map = map
    self.soft_blocks = soft_blocks
    self.items = items
    self.eggs = eggs or {}
    self.bombs = bombs or {}
    return self
end

function scenery.soft_block_at(column: integer, row: integer): SoftBlockConfig
    return map_entities.SoftBlockConfig.new(
        grid.get_tile_position(column, row), nil, false
    )
end

function scenery.item_at(column: integer, row: integer, kind: ItemType): ItemDrop
    return ItemDrop.new(grid.get_tile_position(column, row), kind)
end

function scenery.bomb_at(column: integer, row: integer, fire: integer): StaticBomb
    return StaticBomb.new(grid.get_tile_position(column, row), fire)
end

return scenery
