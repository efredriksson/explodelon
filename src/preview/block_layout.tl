-- The blocks a battle on this map would start with, and the 1-ton blocks
-- falling at speed when the player is looking at their pattern.

local collision = require("engine.collision")
local hard_blocks = require("hard_blocks")
local itertools = require("itertools")
local map_entities = require("level_layout.map_entities")
local pressure_blocks = require("pressure_block")
local settings = require("settings")
local soft_blocks = require("soft_blocks")
local z_index = require("z_index")

local type BlockPattern = settings.BlockPattern
local type Entity = require("engine.entity")
local type FallPattern = settings.FallPattern
local type Group = collision.Group
local type HardBlocks = hard_blocks.HardBlocks
local type Map = settings.Map
local type PressureBlocks = pressure_blocks.PressureBlocks
local type SoftBlocks = soft_blocks.SoftBlocks

-- A battle's worth of 1-ton blocks takes minutes to land, which is longer than
-- anyone will hold the pattern row.
local FALL_SPEED_MULTIPLIER = 8

local record BlockLayoutPreview
    map: Map
    block_pattern: BlockPattern
    fall_pattern: FallPattern
    falling: boolean
    hard_blocks: HardBlocks
    soft_blocks: SoftBlocks
    pressure_blocks: PressureBlocks
    pressure_blocks_group: Group<Entity>
end

local block_layout = {BlockLayoutPreview = BlockLayoutPreview}

function block_layout.new(falling: boolean): BlockLayoutPreview
    local self: BlockLayoutPreview = setmetatable({}, {__index = BlockLayoutPreview})
    self.map = settings.map
    self.block_pattern = settings.get_block_pattern()
    self.fall_pattern = settings.get_fall_pattern()
    self.falling = falling

    local block_configs = map_entities.get_block_configs({})
    self.hard_blocks = hard_blocks.new(block_configs.hard)
    self.soft_blocks = soft_blocks.new(block_configs.soft)
    self.pressure_blocks = pressure_blocks.new(self.fall_pattern)
    self.pressure_blocks.sudden_death = true
    self.pressure_blocks_group = collision.new_group_from_set(
        self.pressure_blocks.on_ground.set
    )
    return self
end

-- Rebuilding on every change is also how the fall animation gets restarted, so
-- the player sees it from the top each time they come back to the row.
function BlockLayoutPreview:is_stale(falling: boolean): boolean
    return self.map ~= settings.map
        or self.block_pattern ~= settings.get_block_pattern()
        or self.fall_pattern ~= settings.get_fall_pattern()
        or self.falling ~= falling
end

function BlockLayoutPreview:update(dt: number)
    if self.falling then
        self.pressure_blocks:update(dt * FALL_SPEED_MULTIPLIER)

        local lookup = collision.new_lookup(
            self.soft_blocks.on_ground.set,
            self.hard_blocks.on_ground.set,
            self.pressure_blocks.on_ground.set
        )
        self.soft_blocks.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
        self.hard_blocks.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
    end

    self.soft_blocks:update(dt)
end

function BlockLayoutPreview:_entities(): {Entity}
    if self.falling then
        return itertools.sets_as_list(
            self.pressure_blocks.on_ground.set,
            self.pressure_blocks:falling(),
            self.hard_blocks.on_ground.set,
            self.soft_blocks.on_ground.set
        )
    end
    return itertools.sets_as_list(
        self.hard_blocks.on_ground.set, self.soft_blocks.on_ground.set
    )
end

function BlockLayoutPreview:_draw_shadows()
    local blocks_with_shadows = itertools.sets_as_list(
        self.pressure_blocks.on_ground.set, self.pressure_blocks:falling()
    )
    for _, block in ipairs(blocks_with_shadows) do
        block:draw_shadow()
    end
end

function BlockLayoutPreview:draw()
    if self.falling then
        self:_draw_shadows()
    end

    local entities = self:_entities()
    table.sort(entities, z_index.back_to_front)
    for _, entity in ipairs(entities) do
        entity:draw()
    end
end

return block_layout
