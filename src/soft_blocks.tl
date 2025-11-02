require("entity")
require("level_map")
local animations = require("animations")
local const = require("const")
local points = require("geometry.points")
local hitboxes = require("hitboxes")
local itertools = require("itertools")


local soft_block_image: Image
local soft_block_breaking_image: Image

global record SoftBlock is Entity, Explodable, ExplosionBlocking, BlocksBombs
	position: Point
    is_exploding: boolean
    in_explosion: boolean
    breaking_animation: Animation
    item: ItemType
    egg: boolean
end

function SoftBlock.new(position: Point, item: ItemType, egg: boolean): SoftBlock
    local self: SoftBlock = setmetatable({}, { __index = SoftBlock })
    self.position = position
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
	return hitboxes.new_block(self.position)
end

function SoftBlock:update(dt: number)
    if self.breaking_animation then
        self.breaking_animation:update(dt)
    end
end

local function center_animation_on_block(animation: Animation, position: Point): Point
	return points.new(
		position.x - (animation.width - const.BLOCK_SIZE) / 2,
		position.y - (animation.height - const.BLOCK_SIZE) / 2
    )
end

function SoftBlock:draw()
    if self.is_exploding then
        local position = center_animation_on_block(
            self.breaking_animation, self.position
        )
        self.breaking_animation:draw(position.x, position.y)
    else
        lutro.graphics.draw(soft_block_image, self.position.x, self.position.y)
    end
end

function SoftBlock:blow_up()
    if self.is_exploding then
        return
    end

    self.is_exploding = true
    self.breaking_animation = animations.new(soft_block_breaking_image, 24, 24, 3, 18)
end

function SoftBlock:is_destroyed(): boolean
    return self.breaking_animation and self.breaking_animation.loops > 0
end

global record SoftBlocks 
	on_ground: {SoftBlock}
end

local soft_blocks = {}

function soft_blocks.new(configs: {SoftBlockConfig}): SoftBlocks
    local self: SoftBlocks = setmetatable({}, { __index = SoftBlocks })
    self.on_ground = {}
    for _, config in ipairs(configs) do
        local block = SoftBlock.new(config.position, config.item, config.egg)
        table.insert(self.on_ground, block)
    end
    return self
end

function SoftBlocks:update(dt: number)
    for i, soft_block in ipairs(self.on_ground) do
        soft_block:update(dt)
        
        if soft_block:is_destroyed() then
            table.remove(self.on_ground, i)
        end
    end
end

function SoftBlocks:hitboxes(): {Rectangle}
    local function hitbox_map_f(block: SoftBlock): Rectangle
        return hitboxes.new_block(block.position)
    end
    return itertools.map(self.on_ground, hitbox_map_f)
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

function SoftBlocks.load_assets()
    soft_block_image = lutro.graphics.newImage("assets/soft-block.png")
    soft_block_breaking_image = lutro.graphics.newImage("assets/soft-block-breaking.png")
end

return soft_blocks
