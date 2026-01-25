local animations = require("engine.animations")
local grid = require("level_layout.grid")
local hard_block_animations = require("level_graphics.hard_block_animations")
local hitboxes = require("engine.hitboxes")
local map_entities = require("level_layout.map_entities")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")

local type Animation = animations.Animation
local type Explodable = require("bombs.explodable")
local type Entity = require("engine.entity")
local type Kinematic = require("kinematic")
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type HardBlockConfig = map_entities.HardBlockConfig

local record HardBlock is Explodable, Kinematic, Entity
	position: Point
	in_explosion: boolean
    animation: Animation
end

function HardBlock.new(position: Point, is_tall: boolean): HardBlock
   local self: HardBlock = setmetatable({}, { __index = HardBlock })
   self.position = position
   self.in_explosion = false
   self.animation = hard_block_animations.get(is_tall)
   return self
end

function HardBlock:get_position(): Point
	return self.position
end

function HardBlock:draw()
    local y_pos = self.position.y - (self.animation.height - grid.TILE_SIZE)
    self.animation:draw(self.position.x, y_pos)
end

function HardBlock:hit_with_bomb()
	-- Does nothing
end

function HardBlock:blow_up()
	-- Does nothing
end

function HardBlock:hitbox(): Rectangle
	return hitboxes.new_block(self.position):shrink(4)
end

function HardBlock:movementbox(): Rectangle
	return hitboxes.new_block(self.position)
end

local record HardBlocks 
	on_ground: {HardBlock}
end

local hard_blocks = {HardBlock = HardBlock, HardBlocks = HardBlocks}

function hard_blocks.new(configs: {HardBlockConfig}): HardBlocks
    local self: HardBlocks = setmetatable({}, { __index = HardBlocks })
    self.on_ground = {}
    for _, config in ipairs(configs) do
        table.insert(self.on_ground, HardBlock.new(config.position, config.is_tall))
    end
    return self
end

return hard_blocks
