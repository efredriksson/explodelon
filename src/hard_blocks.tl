require("level_map")
local const = require("const")
local hitboxes = require("hitboxes")
local settings = require("settings")


local hard_block_image: {Map: {boolean: Image}} = {}

global record HardBlock is ExplosionBlocking, Kinematic, Entity
	position: Point
	in_explosion: boolean
    image: Image
end

function HardBlock.new(position: Point, tall: boolean): HardBlock
   local self: HardBlock = setmetatable({}, { __index = HardBlock })
   self.position = position
   self.in_explosion = false
   self.image = hard_block_image[settings.map][tall]
   return self
end

function HardBlock:get_position(): Point
	return self.position
end

function HardBlock:draw()
    local y_pos = self.position.y - (self.image:getHeight() - const.BLOCK_SIZE)
    lutro.graphics.draw(self.image, self.position.x, y_pos)
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

global record HardBlocks 
	on_ground: {HardBlock}
end

function HardBlocks:exists_at(position: Point): boolean
	for _, hard_block in ipairs(self.on_ground) do
		if hard_block.position:equal(position) then
			return true
		end
	end

	return false
end

local hard_blocks = {}

function hard_blocks.new(configs: {HardBlockConfig}): HardBlocks
    local self: HardBlocks = setmetatable({}, { __index = HardBlocks })
    self.on_ground = {}
    for _, config in ipairs(configs) do
        table.insert(self.on_ground, HardBlock.new(config.position, config.tall))
    end
    return self
end

function hard_blocks.load_assets()
    local maps: {Map} = {"football", "factory"}
    for _, map in ipairs(maps) do
        local asset_dir = "assets/" .. map
        hard_block_image[map] = {}
        hard_block_image[map][false] = lutro.graphics.newImage(asset_dir .. "/hard-block.png")
        hard_block_image[map][true] = lutro.graphics.newImage(asset_dir .. "/hard-block-tall.png")
    end
end

return hard_blocks
