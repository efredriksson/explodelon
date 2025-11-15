local animations = require("animations")
local audio = require("audio")
local hitboxes = require("hitboxes")
local level_map = require("level_map")
local lightings = require("lightings")
local vectors = require("geometry.vectors")

local bomb_shadow: Image
local lighting_bomb_image: Image
local coild_1_effect: Image
local coild_2_effect: Image


global record LightingBomb is Entity, Kinematic
    position: Point
    timer: number
    range: number
    hand_back: function()
    animation: Animation
    buildups: {Animation}
    speedup_at: number
    sound: Source
end

function LightingBomb.new(position: Point, hand_back: function()): LightingBomb
    local self: LightingBomb = setmetatable({}, { __index = LightingBomb })
    self.position = position
    self.range = 6
    self.timer = 5
    self.hand_back = hand_back
    self.animation = animations.new(lighting_bomb_image, 16, 16, 1, 4)
    self.buildups = {
        animations.new(coild_1_effect, 32, 32, 1, 4),
        animations.new(coild_2_effect, 32, 32, 1, 4),
    }
    self.speedup_at = 4
    self.sound = audio.new_source("assets/lighting-bomb/explosion/load.ogg", "static")
    self.sound:play()
    return self
end

function LightingBomb:clear()
    audio.clear(self.sound)
    self.hand_back()
end

function LightingBomb:get_position(): Point
    return self.position
end

function LightingBomb:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(4)
end

function LightingBomb:movementbox(): Rectangle
	return hitboxes.new_block(self.position)
end

function LightingBomb:blow_up()
    self.timer = 0
end

function LightingBomb:hit_with_bomb()
	-- Does nothing
end

function LightingBomb:is_complete(): boolean
    return self.timer <= 0
end

function LightingBomb:draw()
    lutro.graphics.draw(bomb_shadow, self.position.x - 1, self.position.y - 8)
    self.animation:draw(self.position.x, self.position.y)
    local buildup_pos = self.position:move(vectors.new(-8, -8))
    for _, animation in ipairs(self.buildups) do
        animation:draw(buildup_pos.x, buildup_pos.y)
    end
end

function LightingBomb:update(dt: number)
    self.timer = self.timer - dt
    self.animation:update(dt)
    for _, animation in ipairs(self.buildups) do
        animation:update(dt)
    end

    if self.timer < self.speedup_at then
        self.speedup_at = self.speedup_at - 0.5

        for _, animation in ipairs(self.buildups) do
            animation:scale_frame_durations(0.7)
        end
    end

    if self:is_complete() then
        audio.clear(self.sound)
    end
end

global record LightingBombs
    on_ground: {LightingBomb}
    lightings: Lightings
end

local lighting_bombs = {}

function lighting_bombs.load_assets()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    lighting_bomb_image = lutro.graphics.newImage("assets/lighting-bomb/bomb.png")
    coild_1_effect = lutro.graphics.newImage("assets/lighting-bomb/coil-1.png")
    coild_2_effect = lutro.graphics.newImage("assets/lighting-bomb/coil-2.png")
end

function lighting_bombs.new(): LightingBombs
    local self: LightingBombs = setmetatable({}, { __index = LightingBombs })
    self.on_ground = {}
    self.lightings = lightings.new()
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

function LightingBombs:place_lighting_bomb(player: Player, occupied: {Entity})
    local position = level_map.snap_to_closest_grid_tile(player.position)
    if is_occupied_by_bomb(position, occupied) then
        return
    end
    if player.lighting_bomb == 0 then
        return
    end
    
    local hand_back_bomb = function() player.lighting_bomb = player.lighting_bomb + 1 end
    local bomb = LightingBomb.new(position, hand_back_bomb)
    table.insert(self.on_ground, bomb)
    player.lighting_bomb = player.lighting_bomb - 1
end

function LightingBombs:update(dt: number, blockers: {ExplosionBlocking}, explodables: {Player})
    for i, bomb in ipairs(self.on_ground) do
        bomb:update(dt)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            bomb.hand_back()
            self.lightings:place_explosion(bomb.position, bomb.range)
        end
    end

    self.lightings:update(dt, blockers, explodables)
end

return lighting_bombs
