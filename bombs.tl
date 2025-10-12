require("animation")
require("player")
require("explosions")

-- Bomb --

local bomb_shadow: Image
local bomb_image: Image

global record Bomb is Entity
    timer: number
    range: number
    owner: Player
    animation: Animation
end

function Bomb.new(position: Point, player: Player): Bomb
   local self: Bomb = setmetatable({}, { __index = Bomb })
   self.position = position
   self.range = player.fire
   self.timer = 2.5
   self.owner = player
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
    explosions: Explosions
end

function Bombs:load()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    bomb_image = lutro.graphics.newImage("assets/bomb/bomb.png")
end

function Bombs.new(): Bombs
   local self: Bombs = setmetatable({}, { __index = Bombs })
   self.on_ground = {}
   self.explosions = Explosions.new()

   return self
end

function Bombs:place_bomb(position: Point, player: Player): Bomb
    local bomb = Bomb.new(position, player)
    table.insert(self.on_ground, bomb)
    return bomb
end

function Bombs:update(dt: number, blocked: {Point}, explode_targets: {ExplodeTarget})
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            bomb.owner.bombs = bomb.owner.bombs + 1
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

    self.explosions:update(dt, blocked, explode_targets)
end

function Bombs:draw()
    for _, bomb in ipairs(self.on_ground) do
        bomb:draw()
    end

    self.explosions:draw()
end