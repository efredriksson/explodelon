require("animation")
require("player")
require("explosions")
require("physics")

-- Bomb --

local bomb_shadow: Image
local bomb_image: Image

global record Bomb is Entity
    position: Point
    velocity: Vector
    timer: number
    range: number
    owner_id: integer
    has_been_kicked: boolean
    animation: Animation
end

function Bomb.new(position: Point, range: integer, owner_id: integer): Bomb
   local self: Bomb = setmetatable({}, { __index = Bomb })
   self.position = position
   self.velocity = Vector.new(0, 0)
   self.range = range
   self.timer = 2.5
   self.owner_id = owner_id
   self.has_been_kicked = false
   self.animation = Animation.new(bomb_image, 16, 16, 1, 4)
   return self
end

function Bomb:get_position(): Point
    return self.position
end

function Bomb:detonate()
    self.timer = 0
end

function Bomb:is_complete(): boolean
    return self.timer <= 0
end

function Bomb:draw()
    lutro.graphics.draw(bomb_shadow, self.position.x - 1, self.position.y - 8)
    self.animation:draw(self.position.x, self.position.y)
end

function Bomb:can_move(direction: Vector, occupies: {BlocksBombs}): boolean
    local test_position = self.position:move(direction)
    local test_hit_box = new_hitbox(test_position)
    local old_hit_box = new_hitbox(self.position)
    
    local function move_further_into_occupied(block: Rectangle): boolean
		if not test_hit_box:overlap(block) then
			return false
		end

		local new_dist_to_1_ton_block = block:center_distance(test_hit_box)
		local old_dist_to_1_ton_block = block:center_distance(old_hit_box)
		return new_dist_to_1_ton_block < old_dist_to_1_ton_block
	end
    
    local function conflict(occupied: BlocksBombs, hitbox: Rectangle): boolean
        -- Bomb must always be one block away from player
        return occupied:get_position():distance_to(hitbox:top_left()) < BLOCK_SIZE
    end

    for _, occupied in ipairs(occupies) do
        if move_further_into_occupied(new_hitbox(occupied:get_position())) then
            return false
        end

        if not conflict(occupied, old_hit_box) and conflict(occupied, test_hit_box) then
            -- Do not allow bomb move so its hitbox conflicts when it did not before
            return false
        end
    end

    return true
end

function Bomb:update(dt: number, occupies: {BlocksBombs})
    if self.velocity:length() > 0 then
        local new_position = self.position:move(self.velocity:scale(dt))
        if self:can_move(self.velocity:scale(dt), occupies) then
            self.position = new_position
        else
            -- If bomb can't move stop it and snap to grid
            self.velocity = Vector.new(0, 0)
            self.position = snap_to_closest_grid_tile(self.position)
        end
    end
    self.timer = self.timer - dt
    self.animation:update(dt)
end

function Bomb:kick(direction: Vector)
    local slide_speed = 115
    self.velocity = direction:scale(slide_speed)
    self.has_been_kicked = true
end

global record ThrownBomb is Entity
    delegate: Bomb
    target: Point
    direction: Vector
    height: number
    fall_velocity: number
    side_velocity: Vector
    gravity: number
end

function ThrownBomb:_set_trajectory(start_height: number, throw_height: number, throw_time: number)
    self.height = start_height
    self.fall_velocity = get_init_projectile_velocity(
		start_height, throw_height, throw_time
	)
	self.gravity = get_gravity(self.fall_velocity, throw_height)
	
    local throw_vector = Vector.new(
        self.target.x - self.delegate.position.x,
        self.target.y - self.delegate.position.y
    )
    self.side_velocity = throw_vector:scale(1 / throw_time)
    self.direction = throw_vector:normalize()
end

function ThrownBomb.new(delegate: Bomb, target: Point, start_height: number, throw_height: number, throw_time: number): ThrownBomb
    local self: ThrownBomb = setmetatable({}, { __index = ThrownBomb })
    self.delegate = delegate
    self.target = target
    self:_set_trajectory(start_height, throw_height, throw_time)
    return self
end

function ThrownBomb:bounce()
    self.target = self:get_position():move(self.direction:scale(BLOCK_SIZE))
    self:_set_trajectory(0, BLOCK_SIZE * 0.8, 0.25)
end

function ThrownBomb:get_position(): Point
    return self.delegate.position
end

function ThrownBomb:draw()
    local position = self:get_position()
    lutro.graphics.draw(bomb_shadow, position.x - 1, position.y - 8)

    -- Bomb is drawn in the air
    local draw_position = position:move(Vector.new(0, -self.height))
    self.delegate.animation:draw(draw_position.x, draw_position.y)
end

function ThrownBomb:has_landed(): boolean
    return self:get_position():distance_to(self.target) < 1
end

function ThrownBomb:update(dt: number)
    local bomb = self.delegate
    if not self:has_landed() then
        bomb.position = bomb.position:move(self.side_velocity:scale(dt))
        self.height = self.height + self.fall_velocity * dt
        self.fall_velocity = self.fall_velocity - self.gravity * dt
    end

    if self:has_landed() then
        bomb.position = self.target
        self.height = 0
    end

    -- Don't update bomb as time should not change
    bomb.animation:update(dt)
end

-- Bombs --

global record Bombs
    on_ground: {Bomb}
    in_air: {ThrownBomb}
    exploded: {Bomb}
    explosions: Explosions
end

function Bombs:load()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    bomb_image = lutro.graphics.newImage("assets/bomb/bomb.png")
end

function Bombs.new(): Bombs
    local self: Bombs = setmetatable({}, { __index = Bombs })
    self.on_ground = {}
    self.in_air = {}
    self.exploded = {}
    self.explosions = Explosions.new()
    return self
end

function Bombs:place_bomb(player: Player)
    local position = snap_to_closest_grid_tile(player.position)
    for _, existing_bomb in ipairs(self.on_ground) do
        if existing_bomb.position:equal(position) then
            return
        end
    end
    if player.bombs == 0 then
        return
    end
    
    local bomb = Bomb.new(position, player.fire, player.id)
    table.insert(self.on_ground, bomb)
    player.bombs = player.bombs - 1
end

function Bombs:throw_bomb(from: Point, to: Point, by_id: integer): Bomb
    local bomb = Bomb.new(from, 2, by_id)
    local thrown = ThrownBomb.new(bomb, to, BLOCK_SIZE, BLOCK_SIZE * 2, 0.4)
    table.insert(self.in_air, thrown)
    return bomb
end

function Bombs:update(dt: number, blockers: {ExplosionBlocking}, explodables: {Explodable}, occupies: {BlocksBombs})
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt, occupies)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            table.insert(self.exploded, bomb)
            self.explosions:place_explosion(bomb.position, bomb.range)
        end
    end

    for i, bomb in ipairs(self.in_air) do
        bomb:update(dt)
        if bomb:has_landed() then
            local space_is_occupied = false
            for _, occupied in ipairs(occupies) do
                if occupied:get_position():distance_to(bomb.target) < BLOCK_SIZE / 2 then
                    space_is_occupied = true
                    occupied:hit_with_bomb()
                end
            end
            
            if space_is_occupied then
                bomb:bounce()
            else
                table.remove(self.in_air, i)
                table.insert(self.on_ground, bomb.delegate)
            end
        end
    end
    
    for _, explosion in ipairs(self.explosions.on_ground) do
        for _, bomb in ipairs(self.on_ground) do
            if explosion:collides_with(bomb.position) then
                bomb:detonate()
            end
        end
    end

    self.explosions:update(dt, blockers, explodables)
end

function Bombs:draw()
    for _, bomb in ipairs(self.on_ground) do
        bomb:draw()
    end

    self.explosions:draw()
end

function Bombs:to_hand_back(): {Bomb}
    local to_hand_back = self.exploded
    self.exploded = {}
    return to_hand_back
end
