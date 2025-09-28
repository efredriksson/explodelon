require("const")
require("geometry")
require("entity")
require("level_map")


global record PressureBlock is Entity
	falling_position: Point
    position: Point
end

function PressureBlock.new(target: Point): PressureBlock
	local self: PressureBlock = setmetatable({}, { __index = PressureBlock })
	self.falling_position = Point.new(target.x, -BLOCK_SIZE)
    self.position = target
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

function PressureBlock:update(dt: number)
    local block_fall_speed = 285
    self.falling_position.y = math.min(self.position.y, self.falling_position.y + dt * block_fall_speed)
end

function PressureBlock:is_on_ground(): boolean
    return self.falling_position.y == self.position.y
end

global record PressureBlocks is Entity
	next_left_index: integer
    next_right_index: integer
    left_positions: {Point}
    right_positions: {Point}
    left_falling: PressureBlock
    right_falling: PressureBlock
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
    table.insert(self.on_ground, self.right_falling)
    if self.next_right_index <= #self.right_positions then
        self.right_falling = PressureBlock.new(self.right_positions[self.next_right_index])
        self.next_right_index = self.next_right_index + 1
    else
        self.no_more_falling_blocks = true
    end
end

function PressureBlocks:set_next_left_falling_block()
    table.insert(self.on_ground, self.left_falling)
    if self.next_left_index <= #self.left_positions then
        self.left_falling = PressureBlock.new(self.left_positions[self.next_left_index])
        self.next_left_index = self.next_left_index + 1
    else
        self.no_more_falling_blocks = true
    end
end

function PressureBlocks:falling(): {PressureBlock}
    if self:no_updates() then
        return {}
    end
    return {self.left_falling, self.right_falling}
end

function PressureBlocks:update(dt: number): {PressureBlock}
    self.time_left = self.time_left - dt
    if self:no_updates() then
        return {}
    end

    self.left_falling:update(dt)
    self.right_falling:update(dt)
    if self.right_falling:is_on_ground() and self.left_falling:is_on_ground() then
        local hitting_ground = self:falling()
        self:set_next_right_falling_block()
        self:set_next_left_falling_block()
        return hitting_ground
    end

    -- Left and right do not neccessarly hit the ground at same time:
    if self.right_falling:is_on_ground() then
        return {self.right_falling}
    end
    if self.left_falling:is_on_ground() then
        return {self.left_falling}
    end

    return {}
end