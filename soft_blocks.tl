require("geometry")
require("entity")
require("level_map")
require("itertools")
require("animation")

local soft_block_image: Image
local soft_block_breaking_image: Image

global record SoftBlock is Entity, Explodable, ExplosionBlocking
	position: Point
    is_exploding: boolean
    in_explosion: boolean
    breaking_animation: Animation
end

function SoftBlock.new(position: Point): SoftBlock
    local self: SoftBlock = setmetatable({}, { __index = SoftBlock })
    self.position = position
    self.is_exploding = false
    self.in_explosion = false
    return self
end

function SoftBlock:update(dt: number)
    if self.breaking_animation then
        self.breaking_animation:update(dt)
    end
end

local function center_animation_on_block(animation: Animation, position: Point): Point
	return Point.new(
		position.x - (animation.width - BLOCK_SIZE) / 2,
		position.y - (animation.height - BLOCK_SIZE) / 2
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
    self.breaking_animation = Animation.new(soft_block_breaking_image, 24, 24, 3, 18)
end

function SoftBlock:is_destroyed(): boolean
    return self.breaking_animation and self.breaking_animation.loops > 0
end

global record SoftBlocks 
	on_ground: {SoftBlock}
end

function SoftBlocks.new(positions: {Point}): SoftBlocks
    local self: SoftBlocks = setmetatable({}, { __index = SoftBlocks })
    self.on_ground = {}
    for _, position in ipairs(positions) do
        table.insert(self.on_ground, SoftBlock.new(position))
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
        return new_hit_box(block.position) 
    end
    return map(self.on_ground, hitbox_map_f)
end

function SoftBlocks:load_assets()
    soft_block_image = lutro.graphics.newImage("assets/soft-block.png")
    soft_block_breaking_image = lutro.graphics.newImage("assets/soft-block-breaking.png")
end