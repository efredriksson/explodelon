require("animation")
require("player")
require("explosions")
require("physics")

-- Bomb --

local bomb_shadow: Image
local bomb_image: Image

global record Bomb is Entity
    timer: number
    range: number
    owner_id: integer
    animation: Animation
end

function Bomb.new(position: Point, range: integer, owner_id: integer): Bomb
   local self: Bomb = setmetatable({}, { __index = Bomb })
   self.position = position
   self.range = range
   self.timer = 2.5
   self.owner_id = owner_id
   self.animation = Animation.new(bomb_image, 16, 16, 1, 4)
   return self
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

function Bomb:update(dt: number)
    self.timer = self.timer - dt
    self.animation:update(dt)
end

global record ThrownBomb is Entity
    delegate: Bomb
    target: Point
    position: Point
    direction: Vector
    height: number
    fall_velocity: number
    side_velocity: Vector
    gravity: number
end

function ThrownBomb.new(delegate: Bomb, target: Point, start_height: number, throw_height: number, throw_time: number): ThrownBomb
    local self: ThrownBomb = setmetatable({}, { __index = ThrownBomb })
    self.delegate = delegate
    self.position = delegate.position
    self.target = target
    
    self.height = start_height
    self.fall_velocity = get_init_projectile_velocity(
		start_height, throw_height, throw_time
	)
	self.gravity = get_gravity(self.fall_velocity, throw_height)
	
    local throw_vector = Vector.new(
        self.target.x - self.position.x,
        self.target.y - self.position.y
    )
    self.side_velocity = throw_vector:scale(1 / throw_time)
    self.direction = throw_vector:normalize()
    return self
end

function ThrownBomb:draw()
    lutro.graphics.draw(bomb_shadow, self.position.x - 1, self.position.y - 8)
    self.delegate.animation:draw(self.delegate.position.x, self.delegate.position.y)
end

function ThrownBomb:has_landed(): boolean
    return self.position:distance_to(self.target) < 1
end

function ThrownBomb:update(dt: number)
    if not self:has_landed() then
        self.position = self.position:move(self.side_velocity:scale(dt))
        self.height = self.height + self.fall_velocity * dt
        self.fall_velocity = self.fall_velocity - self.gravity * dt
    end

    if self:has_landed() then
        self.position = self.target
        self.height = 0
    end

    -- Bomb delegate position is set as draw position accounting for height
    self.delegate.position = self.position:move(Vector.new(0, -self.height))
    -- Don't update bomb as time should not change
    self.delegate.animation:update(dt)
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

function Bombs:bounce_bomb(bomb: ThrownBomb)
    local bounce_to = bomb.position:move(bomb.direction:scale(BLOCK_SIZE))
    local bouncing_bomb = ThrownBomb.new(bomb.delegate, bounce_to, 0, BLOCK_SIZE * 0.8, 0.25)
    table.insert(self.in_air, bouncing_bomb)
end

function Bombs:update(dt: number, blockers: {ExplosionBlocking}, explodables: {Explodable}, blocks: {Point})
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            table.insert(self.exploded, bomb)
            self.explosions:place_explosion(bomb.position, bomb.range)
        end
    end

    for i, bomb in ipairs(self.in_air) do
        bomb:update(dt)
        if bomb:has_landed() then
            local landed_on_block = false
            for _, block in ipairs(blocks) do
                if block:equal(bomb.target) then
                    landed_on_block = true
                end
            end

            table.remove(self.in_air, i)
            if landed_on_block then
                self:bounce_bomb(bomb)
            else
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
