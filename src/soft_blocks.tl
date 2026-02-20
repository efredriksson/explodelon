local animations = require("engine.animations")
local grid = require("level_layout.grid")
local hitboxes = require("engine.hitboxes")
local map_entities = require("level_layout.map_entities")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local settings = require("settings")
local soft_block_animations = require("level_graphics.soft_block_animations")
local z_index = require("z_index")

local type Animation = animations.Animation
local type Explodable = require("bombs.explodable")
local type Entity = require("engine.entity")
local type Kinematic = require("kinematic")
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type ItemType = settings.ItemType

local record SoftBlock is Entity, Explodable, Kinematic
	position: Point
    is_exploding: boolean
    in_explosion: boolean
    base_animation: Animation
    revealed_animation: Animation
    breaking_animation: Animation
    item: ItemType
    egg: boolean
    is_revealed: boolean
end

function SoftBlock.new(position: Point, base_animation: Animation, revealed_animation: Animation, item: ItemType, egg: boolean): SoftBlock
    local self: SoftBlock = setmetatable({}, { __index = SoftBlock })
    self.position = position
    self.z_index = z_index.LEVEL
    self.base_animation = base_animation
    self.revealed_animation = revealed_animation
    self.breaking_animation = soft_block_animations.get_exploding()
    self.is_exploding = false
    self.in_explosion = false
    self.item = item
    self.egg = egg
    self.is_revealed = false
    return self
end

function SoftBlock:get_position(): Point
    return self.position
end

function SoftBlock:hit_with_bomb()
	-- Does nothing
end

function SoftBlock:reveal()
    if self.egg or self.item then
	    self.is_revealed = true
    end
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
    elseif self.is_revealed then
        self.revealed_animation:draw(self.position.x, self.position.y)
    else
        self.base_animation:draw(self.position.x, self.position.y)
    end
end

function SoftBlock:blow_up()
    self.is_exploding = true
    -- Draw soft blocks exploding above, revealing possible item under it
    self.z_index = z_index.ABOVE
end

function SoftBlock:is_destroyed(): boolean
    return self.breaking_animation.loops > 0
end

local record SoftBlocks 
	on_ground: {SoftBlock}
    rigid_animation: Animation
    revealed_animation: Animation
end

local soft_blocks = {SoftBlocks = SoftBlocks, SoftBlock = SoftBlock}

function soft_blocks.new(configs: {SoftBlockConfig}): SoftBlocks
    local self: SoftBlocks = setmetatable({}, { __index = SoftBlocks })
    self.on_ground = {}
    self.rigid_animation = soft_block_animations.get_rigid()
    self.revealed_animation = soft_block_animations.get_revealed()
    for _, config in ipairs(configs) do
        local block = SoftBlock.new(
            config.position,
            self.rigid_animation,
            self.revealed_animation,
            config.item,
            config.egg
        )
        table.insert(self.on_ground, block)
    end
    return self
end

function SoftBlocks:update(dt: number)
    -- All soft blocks share animations that are in sync
    self.rigid_animation:update(dt)
    self.revealed_animation:update(dt)

    for i = #self.on_ground, 1, -1 do
        local soft_block = self.on_ground[i]
        soft_block:update(dt)

        if soft_block:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
end

return soft_blocks
