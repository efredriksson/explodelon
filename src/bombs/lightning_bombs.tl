local animations = require("engine.animations")
local audio = require("engine.audio")
local collision = require("engine.collision")
local grid = require("level_layout.grid")
local hitboxes = require("engine.hitboxes")
local lightnings = require("bombs.lightnings")
local players = require("players")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local z_index = require("z_index")

local type Animation = animations.Animation
local type Explodable = require("bombs.explodable")
local type Kinematic = require("kinematic")
local type Entity = require("engine.entity")
local type Lightnings = lightnings.Lightnings
local type Player = players.Player
local type Group = collision.Group
local type Lookup = collision.Lookup
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local bomb_shadow: Image
local lightning_bomb_image: Image
local coild_1_effect: Image
local coild_2_effect: Image


local record LightningBomb is Entity, Kinematic
    position: Point
    timer: number
    range: number
    hand_back: function()
    animation: Animation
    buildups: {Animation}
    speedup_at: number
    sound: Source
end

function LightningBomb.new(position: Point, hand_back: function()): LightningBomb
    local self: LightningBomb = setmetatable({}, { __index = LightningBomb })
    self.position = position
    self.z_index = z_index.BELOW
    self.range = 6
    self.timer = 5
    self.hand_back = hand_back
    self.animation = animations.new(lightning_bomb_image, 16, 0.25)
    self.buildups = {
        animations.new(coild_1_effect, 32, 0.25),
        animations.new(coild_2_effect, 32, 0.25),
    }
    self.speedup_at = 4
    self.sound = audio.new_source("assets/lightning-bomb/explosion/load.ogg", "static")
    self.sound:play()
    return self
end

function LightningBomb:clear()
    audio.clear(self.sound)
    self.hand_back()
end

function LightningBomb:get_position(): Point
    return self.position
end

function LightningBomb:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(4)
end

function LightningBomb:movementbox(): Rectangle
	return hitboxes.new_block(self.position)
end

function LightningBomb:blow_up()
    self.timer = 0
end

function LightningBomb:hit_with_bomb()
	-- Does nothing
end

function LightningBomb:is_complete(): boolean
    return self.timer <= 0
end

function LightningBomb:draw()
    lutro.graphics.draw(bomb_shadow, self.position.x - 1, self.position.y - 8)
    self.animation:draw(self.position.x, self.position.y)
    local buildup_pos = self.position:move(vectors.new(-8, -8))
    for _, animation in ipairs(self.buildups) do
        animation:draw(buildup_pos.x, buildup_pos.y)
    end
end

function LightningBomb:update(dt: number)
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

local record LightningBombs
    on_ground: {LightningBomb}
    lightnings: Lightnings
end

local lightning_bombs = {LightningBombs = LightningBombs}

function lightning_bombs.load_assets()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    lightning_bomb_image = lutro.graphics.newImage("assets/lightning-bomb/bomb.png")
    coild_1_effect = lutro.graphics.newImage("assets/lightning-bomb/coil-1.png")
    coild_2_effect = lutro.graphics.newImage("assets/lightning-bomb/coil-2.png")
end

function lightning_bombs.new(): LightningBombs
    local self: LightningBombs = setmetatable({}, { __index = LightningBombs })
    self.on_ground = {}
    self.lightnings = lightnings.new()
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

function LightningBombs:place_lightning_bomb(player: Player, occupied: {Entity})
    local position = grid.snap_to(player.position)
    if is_occupied_by_bomb(position, occupied) then
        return
    end
    if player.lightning_bomb == 0 then
        return
    end
    
    local hand_back_bomb = function() player.lightning_bomb = player.lightning_bomb + 1 end
    local bomb = LightningBomb.new(position, hand_back_bomb)
    table.insert(self.on_ground, bomb)
    player.lightning_bomb = player.lightning_bomb - 1
end

function LightningBombs:update(dt: number, blockers: Group<Explodable>, explodables: Group<Player>, lookup: Lookup)
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            bomb.hand_back()
            self.lightnings:place_explosion(bomb.position, bomb.range)
        end
    end

    self.lightnings:update(dt, blockers, explodables, lookup)
end

return lightning_bombs
