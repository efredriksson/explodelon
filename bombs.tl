require("animation")
require("player")
require("explosions")

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

-- Bombs --

global record Bombs
    on_ground: {Bomb}
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
    self.exploded = {}
    self.explosions = Explosions.new()
    return self
end

function Bombs:place_bomb(position: Point, player: Player): Bomb
    local bomb = Bomb.new(position, player.fire, player.id)
    table.insert(self.on_ground, bomb)
    return bomb
end

function Bombs:update(dt: number, blockers: {ExplosionBlocking}, explodables: {Explodable})
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            table.insert(self.exploded, bomb)
            self.explosions:place_explosion(bomb.position, bomb.range)
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
