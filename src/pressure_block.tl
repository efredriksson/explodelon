local collision = require("engine.collision")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local hitboxes = require("engine.hitboxes")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local settings = require("settings")
local z_index = require("z_index")

local type Explodable = require("bombs.explodable")
local type Entity = require("engine.entity")
local type FallPattern = settings.FallPattern
local type Group = collision.Group
local type Kinematic = require("kinematic")
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local record PressureBlock is Entity, Explodable, Kinematic
    falling_position: Point
    position: Point
    in_explosion: boolean
end

local pressure_block_image: Image
local block_fall_shadow: Image

function PressureBlock.new(target: Point): PressureBlock
    local self: PressureBlock = setmetatable({}, {__index = PressureBlock})
    self.falling_position = points.new(target.x, -grid.TILE_SIZE)
    self.position = target
    self.z_index = z_index.LEVEL
    self.in_explosion = false
    return self
end

function PressureBlock:get_position(): Point
    return self.position
end

function PressureBlock:draw()
    lutro.graphics.draw(
        pressure_block_image, self.falling_position.x, self.falling_position.y
    )
end

function PressureBlock:draw_shadow()
    local shadow_y = self.position.y - 9
    local shadow_x = self.position.x - 1
    lutro.graphics.draw(block_fall_shadow, shadow_x, shadow_y)
end

function PressureBlock:blow_up(_: number)
    -- Does nothing
end

function PressureBlock:hit_with_bomb()
    -- Does nothing
end

function PressureBlock:hitbox(): Rectangle
    -- Not for movement blocking but hitting entities
    return hitboxes.new_block(self.position):shrink(4)
end

function PressureBlock:movementbox(): Rectangle
    return hitboxes.new_block(self.position)
end

function PressureBlock:is_on_ground(): boolean
    return self.falling_position.y == self.position.y
end

function PressureBlock:update(dt: number)
    local block_fall_speed = 285
    self.falling_position.y = math.min(
        self.position.y, self.falling_position.y + dt * block_fall_speed
    )
    if self:is_on_ground() then
        self.z_index = z_index.BELOW
    end
end

local record PressureBlockSide
    positions: {Point}
    next_index: integer
    falling: PressureBlock
    fall_finished: boolean
    on_ground: Group<PressureBlock>
end

function PressureBlockSide.new(
    positions: {Point}, on_ground: Group<PressureBlock>
): PressureBlockSide
    local self: PressureBlockSide = setmetatable({}, {__index = PressureBlockSide})
    self.positions = positions
    self.on_ground = on_ground
    self.falling = PressureBlock.new(positions[1])
    self.next_index = 2
    self.fall_finished = false
    return self
end

function PressureBlockSide:set_next_falling_block(): boolean
    if self.next_index > #self.positions then
        return false
    end
    self.fall_finished = false
    self.falling = PressureBlock.new(self.positions[self.next_index])
    self.next_index = self.next_index + 1
    return true
end

function PressureBlockSide:update(dt: number)
    self.falling:update(dt)
    if self.falling:is_on_ground() and not self.fall_finished then
        self.fall_finished = true
        self.on_ground:add(self.falling)
    end
end

local record PressureBlocks
    falling_sides: {PressureBlockSide}
    on_ground: Group<PressureBlock>
    no_more_falling_blocks: boolean
    sudden_death: boolean
end

local pressure_blocks = {PressureBlocks = PressureBlocks, PressureBlock = PressureBlock}

function pressure_blocks.new(fall_pattern: FallPattern): PressureBlocks
    local self: PressureBlocks = setmetatable({}, {__index = PressureBlocks})
    self.on_ground = collision.new_group()
    local function new_side(positions: {Point}): PressureBlockSide
        return PressureBlockSide.new(positions, self.on_ground)
    end
    self.falling_sides = itertools.map(
        map_entities.get_fall_pattern_positions(fall_pattern), new_side
    )
    self.no_more_falling_blocks = false
    self.sudden_death = false
    return self
end

function PressureBlocks:no_updates(): boolean
    return self.no_more_falling_blocks or not self.sudden_death
end

local function side_is_finished(side: PressureBlockSide): boolean
    return side.fall_finished
end

function PressureBlocks:_advance_all_sides()
    local exists_more_falling_blocks = false
    for _, side in ipairs(self.falling_sides) do
        if side:set_next_falling_block() then
            exists_more_falling_blocks = true
        end
    end

    self.no_more_falling_blocks = not exists_more_falling_blocks
end

function PressureBlocks:falling(): {PressureBlock: PressureBlock}
    if self:no_updates() then
        return {}
    end
    local blocks: {PressureBlock: PressureBlock} = {}
    for _, side in ipairs(self.falling_sides) do
        blocks[side.falling] = side.falling
    end
    return blocks
end

function PressureBlocks:update(dt: number)
    if self:no_updates() then
        return
    end

    for _, side in ipairs(self.falling_sides) do
        side:update(dt)
    end

    if itertools.count(self.falling_sides, side_is_finished) == #self.falling_sides then
        self:_advance_all_sides()
    end
end

function pressure_blocks.load_assets()
    pressure_block_image = lutro.graphics.newImage("assets/1_ton.png")
    block_fall_shadow = lutro.graphics.newImage("assets/items/shadow.png")
end

return pressure_blocks
