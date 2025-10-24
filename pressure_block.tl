require("const")
require("geometry")
require("entity")
require("itertools")
require("level_map")
require("hitboxes")


global record PressureBlock is Entity, ExplosionBlocking
	falling_position: Point
    position: Point
    in_explosion: boolean
end

function PressureBlock.new(target: Point): PressureBlock
	local self: PressureBlock = setmetatable({}, { __index = PressureBlock })
	self.falling_position = Point.new(target.x, -BLOCK_SIZE)
    self.position = target
    self.in_explosion = false
	return self
end

global function load_pressure_block_assets()
    global pressure_block_image = lutro.graphics.newImage("assets/1_ton.png")
    global block_fall_shadow = lutro.graphics.newImage("assets/items/shadow.png")
end

function PressureBlock:draw()
    lutro.graphics.draw(pressure_block_image, self.falling_position.x, self.falling_position.y)
end

function PressureBlock:draw_shadow()
    local shadow_y = self.position.y - 9
    local shadow_x = self.position.x - 1
    lutro.graphics.draw(block_fall_shadow, shadow_x, shadow_y)
end

function PressureBlock:blow_up()
    -- Does nothing
end

function PressureBlock:update(dt: number)
    local block_fall_speed = 285
    self.falling_position.y = math.min(self.position.y, self.falling_position.y + dt * block_fall_speed)
end

function PressureBlock:is_on_ground(): boolean
    return self.falling_position.y == self.position.y
end

global record PressureBlocks
	next_left_index: integer
    next_right_index: integer
    left_positions: {Point}
    right_positions: {Point}
    left_falling: PressureBlock
    right_falling: PressureBlock
    right_fall_finished: boolean
    left_fall_finished: boolean
    on_ground: {PressureBlock}
    no_more_falling_blocks: boolean
    time_left: number
end

function PressureBlocks.new(time_left: number): PressureBlocks
	local self: PressureBlocks = setmetatable({}, { __index = PressureBlocks })
    self.left_positions = get_left_side_pressure_blocks()
    self.right_positions = get_right_side_pressure_blocks()
    self.on_ground = {}
    self.left_falling = PressureBlock.new(self.left_positions[1])
    self.right_falling = PressureBlock.new(self.right_positions[1])
    self.next_left_index = 2
    self.next_right_index = 2
    self.right_fall_finished = false
    self.left_fall_finished = false
    self.time_left = time_left
    self.no_more_falling_blocks = false
	return self
end

function PressureBlocks:no_updates(): boolean
    local time_to_start_dropping_pressure_blocks = 60
    return self.no_more_falling_blocks or
        (self.time_left > time_to_start_dropping_pressure_blocks)
end

function PressureBlocks:set_next_right_falling_block()
    self.right_fall_finished = false
    if self.next_right_index <= #self.right_positions then
        self.right_falling = PressureBlock.new(self.right_positions[self.next_right_index])
        self.next_right_index = self.next_right_index + 1
    else
        self.no_more_falling_blocks = true
    end
end

function PressureBlocks:set_next_left_falling_block()
    self.left_fall_finished = false
    if self.next_left_index <= #self.left_positions then
        self.left_falling = PressureBlock.new(self.left_positions[self.next_left_index])
        self.next_left_index = self.next_left_index + 1
    else
        self.no_more_falling_blocks = true
    end
end

function PressureBlocks:falling(): {PressureBlock}
    local falling_blocks = {}
    
    if self:no_updates() then
        return falling_blocks
    end
    
    for _, block in ipairs({self.left_falling, self.right_falling}) do
        if not block:is_on_ground() then
            table.insert(falling_blocks, block)
        end
    end

    return falling_blocks
end

function PressureBlocks:update(dt: number): {PressureBlock}
    self.time_left = self.time_left - dt
    local blocks_hitting_ground: {PressureBlock} = {}
    if self:no_updates() then
        return blocks_hitting_ground
    end

    self.left_falling:update(dt)
    self.right_falling:update(dt)

    if self.right_falling:is_on_ground() and not self.right_fall_finished then
        self.right_fall_finished = true
        table.insert(self.on_ground, self.right_falling)
        table.insert(blocks_hitting_ground, self.right_falling)
    end
    if self.left_falling:is_on_ground() and not self.left_fall_finished then
        self.left_fall_finished = true
        table.insert(self.on_ground, self.left_falling)
        table.insert(blocks_hitting_ground, self.left_falling)
    end

    if self.left_fall_finished and self.right_fall_finished then
        self:set_next_right_falling_block()
        self:set_next_left_falling_block()
    end

    return blocks_hitting_ground
end

function PressureBlocks:hitboxes(): {Rectangle}
    local function hitbox_map_f(block: PressureBlock): Rectangle
        return new_hitbox(block.position) 
    end
    return map(self.on_ground, hitbox_map_f)
end
