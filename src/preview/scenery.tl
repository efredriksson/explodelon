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

local record Scenery
    map: Map
    soft_blocks: {SoftBlockConfig}
    items: {ItemDrop}
end

local scenery = {
    Scenery = Scenery,
}

function scenery.new(
    map: Map, soft_blocks: {SoftBlockConfig}, items: {ItemDrop}
): Scenery
    local self: Scenery = setmetatable({}, {__index = Scenery})
    self.map = map
    self.soft_blocks = soft_blocks
    self.items = items
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

return scenery
