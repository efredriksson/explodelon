local audio = require("engine.audio")
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
end

-- Each side drops its next block after DROP_INTERVAL, whether or not its last
-- one is down yet, and a block falls from where it comes into view above the
-- arena.
local DROP_INTERVAL = 38 / 60
local FALL_SPEED = 240
local FALL_STARTS_ABOVE_TOP_ROW = 40

local pressure_block_image: Image
local block_fall_shadow: Image
local first_fall_sound: Source
local land_sound: Source

function PressureBlock.new(target: Point): PressureBlock
    local self: PressureBlock = setmetatable({}, {__index = PressureBlock})
    local top_row = grid.get_tile_position(0, 0)
    self.falling_position = points.new(target.x, top_row.y - FALL_STARTS_ABOVE_TOP_ROW)
    self.position = target
    self.z_index = z_index.LEVEL
    self.meets_flame = "blocks"
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
    self.falling_position.y = math.min(
        self.position.y, self.falling_position.y + dt * FALL_SPEED
    )
    if self:is_on_ground() then
        self.z_index = z_index.BELOW
    end
end

local record PressureBlockSide
    positions: {Point}
    next_index: integer
    next_drop_in: number
end

function PressureBlockSide.new(positions: {Point}): PressureBlockSide
    local self: PressureBlockSide = setmetatable({}, {__index = PressureBlockSide})
    self.positions = positions
    self.next_index = 1
    self.next_drop_in = 0
    return self
end

function PressureBlockSide:has_dropped_all(): boolean
    return self.next_index > #self.positions
end

--- The blocks whose turn has come, with `dt` then counted off the wait for the next.
function PressureBlockSide:drop(dt: number): {PressureBlock}
    local dropped: {PressureBlock} = {}
    while self.next_drop_in <= 0 and not self:has_dropped_all() do
        table.insert(dropped, PressureBlock.new(self.positions[self.next_index]))
        self.next_index = self.next_index + 1
        self.next_drop_in = self.next_drop_in + DROP_INTERVAL
    end
    self.next_drop_in = self.next_drop_in - dt
    return dropped
end

local record PressureBlocks
    sides: {PressureBlockSide}
    in_air: {PressureBlock}
    on_ground: Group<PressureBlock>
    dropping: boolean
    silent: boolean
    has_started: boolean
end

local pressure_blocks = {PressureBlocks = PressureBlocks, PressureBlock = PressureBlock}

function pressure_blocks.new(
    fall_pattern: FallPattern, silent?: boolean
): PressureBlocks
    local self: PressureBlocks = setmetatable({}, {__index = PressureBlocks})
    self.on_ground = collision.new_group()
    self.in_air = {}
    self.sides = itertools.map(
        map_entities.get_fall_pattern_positions(fall_pattern), PressureBlockSide.new
    )
    self.dropping = false
    self.silent = silent or false
    self.has_started = false
    return self
end

function PressureBlocks:_play(sound: Source)
    if not self.silent then
        sound:play()
    end
end

function PressureBlocks:falling(): {PressureBlock: PressureBlock}
    local blocks: {PressureBlock: PressureBlock} = {}
    for _, block in ipairs(self.in_air) do
        blocks[block] = block
    end
    return blocks
end

function PressureBlocks:_drop_more(dt: number)
    if not self.has_started then
        self.has_started = true
        self:_play(first_fall_sound)
    end
    for _, side in ipairs(self.sides) do
        for _, block in ipairs(side:drop(dt)) do
            table.insert(self.in_air, block)
        end
    end
end

--- Whether a block came down.
function PressureBlocks:_land_those_that_are_down(): boolean
    local landed = false
    for i = #self.in_air, 1, -1 do
        if self.in_air[i]:is_on_ground() then
            self.on_ground:add(table.remove(self.in_air, i))
            landed = true
        end
    end
    return landed
end

--- No block starts to fall while `dropping` is off, but one that is in the air
-- comes down all the same.
function PressureBlocks:update(dt: number)
    if self.dropping then
        self:_drop_more(dt)
    end
    for _, block in ipairs(self.in_air) do
        block:update(dt)
    end
    -- A block that lands cuts off the sound of the one before it. Left to ring
    -- out, the landings pile up on each other.
    if self:_land_those_that_are_down() and not self.silent then
        audio.restart(land_sound)
    end
end

function pressure_blocks.load_assets()
    pressure_block_image = lutro.graphics.newImage("assets/1_ton.png")
    block_fall_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    first_fall_sound = audio.new_source_pool("assets/sfx/sudden_death.wav", "static", 1)
    land_sound = audio.new_source("assets/sfx/pressure_block_land.wav", "static")
    -- At full volume a landing is as loud as an explosion.
    land_sound:setVolume(0.5)
end

return pressure_blocks
