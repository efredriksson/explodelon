require("collision")
local animations = require("animations")
local const = require("const")
local explosions = require("explosions")
local hitboxes = require("hitboxes")
local itertools = require("itertools")
local level_map = require("level_map")
local physics = require("physics")
local vectors = require("geometry.vectors")


-- Bomb --

local bomb_shadow: Image
local bomb_image: Image

global record Bomb is Entity, Kinematic, Explodable
    position: Point
    velocity: Vector
    timer: number
    range: number
    hand_back: function()
    has_been_kicked: boolean
    animation: Animation
end

function Bomb.new(position: Point, range: integer, hand_back: function()): Bomb
   local self: Bomb = setmetatable({}, { __index = Bomb })
   self.position = position
   self.velocity = vectors.new(0, 0)
   self.range = range
   self.timer = 2.5
   self.hand_back = hand_back
   self.has_been_kicked = false
   self.animation = animations.new(bomb_image, 16, 16, 1, 4)
   return self
end

function Bomb:get_position(): Point
    return self.position
end

function Bomb:clear()
    self.hand_back()
end

function Bomb:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(4)
end

function Bomb:movementbox(): Rectangle
	return hitboxes.new_block(self.position)
end

function Bomb:blow_up()
    self.timer = 0
end

function Bomb:hit_with_bomb()
	-- Does nothing
end

function Bomb:get_goal(): Goal
    for _, goal in ipairs(level_map.get_goals()) do
        if self.position:distance_to(goal.position) < 3 then
            return goal
        end
    end

    return nil
end

function Bomb:is_complete(): boolean
    if self:get_goal() then
        return true
    end

    return self.timer <= 0 and self.position:equal(
        level_map.snap_to_closest_grid_tile(self.position)
    )
end

function Bomb:draw()
    lutro.graphics.draw(bomb_shadow, self.position.x - 1, self.position.y - 8)
    self.animation:draw(self.position.x, self.position.y)
end

function Bomb:_trigger_belt(direction?: Vector): ConveyorBelt | nil
    local bomb_move_dir = direction or self.velocity

    local function bomb_on(belt: ConveyorBelt): boolean
        return belt:get_hitbox():overlap(self:movementbox())
    end
    local belts = itertools.filter(level_map.get_conveyor_belts(), bomb_on)
    for _, belt in ipairs(belts) do
        if self.position:distance_to(level_map.snap_to_closest_grid_tile(self.position)) <= 3 then
            local snap_pos = level_map.snap_to_closest_grid_tile(self.position)
            if snap_pos:equal(belt.position) and not belt.direction:same_direction(bomb_move_dir) then
                return belt
            end
        end
    end
end

local function moving_outside_of_map(test_hitbox: Rectangle): boolean
    local bomb_in_goal = false
    for _, goal in ipairs(level_map.get_goals()) do
        if test_hitbox:overlap(goal:get_hitbox()) then
            bomb_in_goal = true
        end
    end

    return not level_map.player_area():contains(test_hitbox) and not bomb_in_goal
end

function Bomb:can_move(direction: Vector, occupies: Group<Kinematic>, interacts_with_bombs: Group<Kinematic>, lookup: Lookup): boolean
    local test_hitbox =  self:movementbox():shift(direction)
    local old_hitbox = self:movementbox()

    local belt_trigger = self:_trigger_belt(direction)
    if not belt_trigger is nil then
        direction = belt_trigger.direction:scale(direction:length())
    end

    if moving_outside_of_map(test_hitbox) then
        return false
    end

    local function move_further_into_occupied(block: Rectangle): boolean
		if not test_hitbox:overlap(block) then
			return false
		end

		local new_dist_to_1_ton_block = block:center_distance(test_hitbox)
		local old_dist_to_1_ton_block = block:center_distance(old_hitbox)
		return new_dist_to_1_ton_block < old_dist_to_1_ton_block
	end
    
    local function conflict(occupied: Kinematic, hitbox: Rectangle): boolean
        -- Bomb must always be one block away from player
        return occupied:movementbox():overlap(hitbox)
    end

    local function not_this_bomb(occupied: Kinematic): boolean
        return occupied ~= self
    end

    local close_occupies = lookup:in_box_and_group(old_hitbox:expand(const.BLOCK_SIZE), occupies)
    for _, occupied in ipairs(close_occupies) do
        if move_further_into_occupied(occupied:movementbox()) then
            return false
        end
    end

    local close_interacts = lookup:in_box_and_group(old_hitbox:expand(const.BLOCK_SIZE), interacts_with_bombs)
    for _, interact in ipairs(itertools.filter(close_interacts, not_this_bomb)) do
        if move_further_into_occupied(interact:movementbox()) then
            return false
        end

        if not conflict(interact, old_hitbox) and conflict(interact, test_hitbox) then
            -- Do not allow bomb move so its hitbox conflicts when it did not before
            return false
        end
    end

    return true
end

function Bomb:update(dt: number, occupies: Group<Kinematic>, interacts_with_bombs: Group<Kinematic>, lookup: Lookup)
    self.timer = self.timer - dt
    
    if self.velocity:length() > 0 then
        local belt_trigger = self:_trigger_belt()
        if not belt_trigger is nil then
            self.position = belt_trigger.position
            self.velocity = belt_trigger.direction:scale(self.velocity:length())
        end

        local new_position = self.position:move(self.velocity:scale(dt))
        if self:can_move(self.velocity:scale(dt), occupies, interacts_with_bombs, lookup) then
            self.position = new_position
        else
            -- If bomb can't move stop it and snap to grid
            self.velocity = vectors.new(0, 0)
            self.position = level_map.snap_to_closest_grid_tile(self.position)
        end

        if self.timer <= 0 then
            -- If bomb timer is up, snap to closest tile if it is close enough.
            -- This is to explode bomb on the grid. Bomb can slide to next intersection!
            if self.position:distance_to(level_map.snap_to_closest_grid_tile(self.position)) <= 3 then
                self.position = level_map.snap_to_closest_grid_tile(self.position)
            end
        end
    end

    self.animation:update(dt)
end

function Bomb:kick(direction: Vector)
    local slide_speed = 120
    self.velocity = direction:scale(slide_speed)
    self.has_been_kicked = true
end

global record ThrownBomb is Entity
    delegate: Bomb
    previous_position: Point
    target: Point
    direction: Vector
    height: number
    fall_velocity: number
    side_velocity: Vector
    gravity: number
end

function ThrownBomb:_set_trajectory(start_height: number, throw_height: number, throw_time: number)
    self.height = start_height
    self.fall_velocity = physics.calc_init_projectile_velocity(
		start_height, throw_height, throw_time
	)
	self.gravity = physics.calc_gravity(self.fall_velocity, throw_height)
	
    local throw_vector = vectors.new(
        self.target.x - self.delegate.position.x,
        self.target.y - self.delegate.position.y
    )
    self.side_velocity = throw_vector:scale(1 / throw_time)
    self.direction = throw_vector:normalize()
end

function ThrownBomb.new(delegate: Bomb, target: Point, start_height: number, throw_height: number, throw_time: number): ThrownBomb
    local self: ThrownBomb = setmetatable({}, { __index = ThrownBomb })
    self.delegate = delegate
    self.previous_position = self.delegate.position
    self.target = target
    self:_set_trajectory(start_height, throw_height, throw_time)
    return self
end

function ThrownBomb:bounce()
    self.target = self:get_position():move(self.direction:scale(const.BLOCK_SIZE))
    self:_set_trajectory(0, const.BLOCK_SIZE * 0.8, 0.25)
end

function ThrownBomb:hitbox(): Rectangle
    return hitboxes.new_block(self:get_position())
end

function ThrownBomb:get_position(): Point
    return self.delegate.position
end

function ThrownBomb:draw()
    local position = self:get_position()
    lutro.graphics.draw(bomb_shadow, position.x - 1, position.y - 8)

    -- Bomb is drawn in the air
    local draw_position = position:move(vectors.new(0, -self.height))
    self.delegate.animation:draw(draw_position.x, draw_position.y)
end

function ThrownBomb:has_landed(): boolean
    if self:get_position():equal(self.target) then
        return true
    end
    return self:get_position():distance_to(self.target) > self.previous_position:distance_to(self.target)
end

function ThrownBomb:update(dt: number)
    local bomb = self.delegate
    if not self:has_landed() then
        self.previous_position = bomb.position
        bomb.position = bomb.position:move(self.side_velocity:scale(dt))
        self.height = self.height + self.fall_velocity * dt
        self.fall_velocity = self.fall_velocity - self.gravity * dt
    end

    if self:has_landed() then
        bomb.position = self.target
        self.previous_position = self.target
        self.height = 0
    end

    -- Don't update bomb as time should not change
    bomb.animation:update(dt)
end

-- Bombs --

global record Bombs
    on_ground: {Bomb}
    in_air: {ThrownBomb}
    explosions: Explosions
end

local bombs = {}

function bombs.load_assets()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    bomb_image = lutro.graphics.newImage("assets/bomb/bomb.png")
end

function bombs.new(): Bombs
    local self: Bombs = setmetatable({}, { __index = Bombs })
    self.on_ground = {}
    self.in_air = {}
    self.explosions = explosions.new()
    return self
end

local function is_occupied_by_bomb(position: Point, existing_bombs: {Entity}): boolean
    for _, existing_bomb in ipairs(existing_bombs) do
        if existing_bomb:get_position():equal(position) then
            return true
        end
    end

    return false
end

function Bombs:place_bomb(player: Player, occupied: {Entity})
    local position = level_map.snap_to_closest_grid_tile(player.position)
    if is_occupied_by_bomb(position, occupied) then
        return
    end
    if player.bombs == 0 then
        return
    end
    
    local hand_back_bomb = function() player.bombs = player.bombs + 1 end
    local bomb = Bomb.new(position, player.fire, hand_back_bomb)
    table.insert(self.on_ground, bomb)
    player.bombs = player.bombs - 1
end

function Bombs:throw_bomb(from: Point, to: Point): Bomb
    local bomb = Bomb.new(from, 2, function() end)
    local thrown = ThrownBomb.new(bomb, to, const.BLOCK_SIZE, const.BLOCK_SIZE * 2, 0.4)
    table.insert(self.in_air, thrown)
    return bomb
end

function Bombs:update(dt: number, blockers: Group<ExplosionBlocking>, explodables: Group<Explodable>, occupies: Group<Kinematic>, interacts_with_bombs: Group<Kinematic>, lookup: Lookup)
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt, occupies, interacts_with_bombs, lookup)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            bomb.hand_back()
            local goal = bomb:get_goal()
            if not goal then
                self.explosions:place_explosion(bomb.position, bomb.range)
            else
                self.explosions:place_explosion(goal.position, 16)
                self.explosions:place_explosion(goal.pair, 14, 0.072)
            end
        end
    end

    for i, bomb in ipairs(self.in_air) do
        bomb:update(dt)
        if bomb:has_landed() then
            local hitting_entities = lookup:collisions_between({bomb}, occupies)
            local bomb_bouncing = false
            for _, hitting_entity in pairs(hitting_entities) do
                hitting_entity:hit_with_bomb()
                bomb_bouncing = true
            end
            
            if bomb_bouncing then
                bomb:bounce()
            else
                table.remove(self.in_air, i)
                table.insert(self.on_ground, bomb.delegate)
            end
        end
    end

    self.explosions:update(dt, blockers, explodables, lookup)
end

return bombs
