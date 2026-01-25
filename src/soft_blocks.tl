require("bombs.explodable")
require("engine.entity")
require("kinematic")
require("level_layout.map_entities")
local grid = require("level_layout.grid")
local hitboxes = require("engine.hitboxes")
local itertools = require("itertools")
local points = require("engine.geometry.points")
local soft_block_animations = require("level_graphics.soft_block_animations")


global record SoftBlock is Entity, Explodable, Kinematic
	position: Point
    is_exploding: boolean
    in_explosion: boolean
    animation: Animation
    breaking_animation: Animation
    item: ItemType
    egg: boolean
end

function SoftBlock.new(position: Point, animation: Animation, item: ItemType, egg: boolean): SoftBlock
    local self: SoftBlock = setmetatable({}, { __index = SoftBlock })
    self.position = position
    self.animation = animation
    self.breaking_animation = soft_block_animations.get_exploding()
    self.is_exploding = false
    self.in_explosion = false
    self.item = item
    self.egg = egg
    return self
end

function SoftBlock:get_position(): Point
    return self.position
end

function SoftBlock:hit_with_bomb()
	-- Does nothing
end

function SoftBlock:hitbox(): Rectangle
	return hitboxes.new_block(self.position):shrink(4)
end

function SoftBlock:movementbox(): Rectangle
	return hitboxes.new_block(self.position)
end

function SoftBlock:update(dt: number)
    if self.is_exploding then
        self.breaking_animation:update(dt)
    end
end

local function center_animation_on_block(animation: Animation, position: Point): Point
	return points.new(
		position.x - (animation.width - grid.TILE_SIZE) / 2,
		position.y - (animation.height - grid.TILE_SIZE) / 2
    )
end

function SoftBlock:draw()
    if self.is_exploding then
        local position = center_animation_on_block(
            self.breaking_animation, self.position
        )
        self.breaking_animation:draw(position.x, position.y)
    else
        self.animation:draw(self.position.x, self.position.y)
    end
end

function SoftBlock:blow_up()
    self.is_exploding = true
end

function SoftBlock:is_destroyed(): boolean
    return self.breaking_animation.loops > 0
end

global record SoftBlocks 
	on_ground: {SoftBlock}
    rigid_animation: Animation
end

local soft_blocks = {}

function soft_blocks.new(configs: {SoftBlockConfig}): SoftBlocks
    local self: SoftBlocks = setmetatable({}, { __index = SoftBlocks })
    self.on_ground = {}
    self.rigid_animation = soft_block_animations.get_rigid()
    for _, config in ipairs(configs) do
        local block = SoftBlock.new(config.position, self.rigid_animation, config.item, config.egg)
        table.insert(self.on_ground, block)
    end
    return self
end

function SoftBlocks:update(dt: number)
    -- All soft blocks share animations that are in sync
    self.rigid_animation:update(dt)

    for i, soft_block in ipairs(self.on_ground) do
        soft_block:update(dt)
        
        if soft_block:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
end

local is_exploding = function(block: SoftBlock): boolean
    return block.is_exploding
end
local is_not_exploding = function(block: SoftBlock): boolean
    return not block.is_exploding
end

function SoftBlocks:exploding(): {SoftBlock}
    return itertools.filter(self.on_ground, is_exploding)
end

function SoftBlocks:not_exploding(): {SoftBlock}
    return itertools.filter(self.on_ground, is_not_exploding)
end

return soft_blocks
