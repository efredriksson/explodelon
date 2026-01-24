require("collision")
require("players")
local animations = require("animations")
local audio = require("audio")
local const = require("const")
local grid = require("level_layout.grid")
local hitboxes = require("hitboxes")
local points = require("geometry.points")

local END_ANIMATION_DURATION: number = 0.6
local FRAME_DURATION = END_ANIMATION_DURATION / 4

local lightning_initial_image: Image
local lightning_ending_image: Image
local lightning_sound: Source

global record LightningAnimations
    ending: Animation
    initial: Animation
end

local record LightningTile is Entity
    position: Point
    reduction: integer
end

function LightningTile.new(position: Point): LightningTile
    local self: LightningTile = setmetatable({}, { __index = LightningTile })
    self.position = position
    self.reduction = 4
    return self
end

function LightningTile:get_position(): Point
    return self.position
end

function LightningTile:draw()
    assert(false, "Not implemented")
end

function LightningTile:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(self.reduction)
end

global record Lightning
    position: Point
    range: number
    duration: number
    speed: number
    tiles: {LightningTile}
    animations: LightningAnimations
end

function Lightning.new(position: Point, range: number): Lightning
    local self: Lightning = setmetatable({}, { __index = Lightning })
    self.position = position
    self.range = range
    self.tiles = {}
    self.duration = 0
    self.speed = 8
    self.animations = {
        initial = animations.new(lightning_initial_image, 16, FRAME_DURATION / 2),
        ending = animations.new(lightning_ending_image, 16, FRAME_DURATION)
    }

    return self
end

function Lightning:play_sound()
    lightning_sound:play()
end

function Lightning:get_position(): Point
    return self.position
end

function Lightning:has_reached_max_range(): boolean
    return self.duration >= self.range / self.speed
end

local function clamp(val: number, min: number, max: number): number
	return math.min(math.max(val, min), max)
end

function Lightning:_update_active_tiles(blockers: Group<ExplosionBlocking>, lookup: Lookup)
    self.tiles = {}

    -- Calculate how far the lightning have expanded
    local current_radius = math.floor(clamp(self.duration * self.speed, 1, self.range))

    local function generate_manhattan_points(position: Point, radius: integer): {Point}
        local manhattan_points: {Point} = {}
        local x = position.x
        local y = position.y
        local function add_points_for(offset: number, r: number)
            -- Add points from square at radius 'r' with some 'offset' from 'corners'
            local inv_offset = r - offset
            table.insert(manhattan_points, points.new(x + offset, y + inv_offset))
            table.insert(manhattan_points, points.new(x + inv_offset, y - offset))
            table.insert(manhattan_points, points.new(x - offset, y - inv_offset))
            table.insert(manhattan_points, points.new(x - inv_offset, y + offset))
        end
        
        for ring=0, radius-1 do
            local radius_pixels = ring * const.BLOCK_SIZE
            for offset=0, ring do
                local offset_pixels = offset * const.BLOCK_SIZE
                add_points_for(offset_pixels, radius_pixels)
            end
        end

        return manhattan_points
    end

    local function is_not_blocked(tile: LightningTile): boolean
        if not grid.area():contains(tile:hitbox()) then
            return false
        end

        for _, _ in pairs(lookup:collisions_between({tile}, blockers)) do
            return false
        end

        return true
    end

    local lightning_at = generate_manhattan_points(self.position, current_radius)
    for _, lightning_pos in ipairs(lightning_at) do
        local new_tile = LightningTile.new(lightning_pos)
        if is_not_blocked(new_tile) then
            table.insert(self.tiles, new_tile)
        end
    end
end

function Lightning:collides_with(explodable: Explodable): boolean
    for _, tile in ipairs(self.tiles) do
        if explodable:hitbox():overlap(tile:hitbox()) then
            return true
        end
    end

    return false
end

function Lightning:is_complete(): boolean
    return self.animations.ending.loops > 0
end

function Lightning:initial_complete(): boolean
    return self.animations.initial.loops > 1
end

function Lightning:_get_animation(): Animation
    if self.animations.initial.loops > 1 then
        return self.animations.ending
    else
        return self.animations.initial
    end
end

function Lightning:draw()
    for _, tile in ipairs(self.tiles) do
        self:_get_animation():draw(tile.position.x, tile.position.y)
        hitboxes.draw(tile:hitbox())
    end
end

function Lightning:update(dt: number, blockers: Group<ExplosionBlocking>, lookup: Lookup)
    self.duration = self.duration + dt
    self:_update_active_tiles(blockers, lookup)
    self:_get_animation():update(dt)
end

-- Explosions --
global record Lightnings
    on_ground: {Lightning}
end

local lightnings = {}

function lightnings.load_assets()
    lightning_initial_image = lutro.graphics.newImage("assets/lightning-bomb/explosion/explosion_center.png")
    lightning_ending_image = lutro.graphics.newImage("assets/lightning-bomb/explosion/explosion_end.png")

    lightning_sound = audio.new_source_pool("assets/lightning-bomb/explosion/detonate.ogg", "static", 5)
    lightning_sound:setPitch(0.75)
end

function lightnings.new(): Lightnings
   local self: Lightnings = setmetatable({}, { __index = Lightnings })
   self.on_ground = {}
   return self
end

function Lightnings:place_explosion(position: Point, range: number)
    local explosion = Lightning.new(position, range)
    explosion:play_sound()
    table.insert(self.on_ground, explosion)
end

function Lightnings:update(dt: number, blockers: Group<ExplosionBlocking>, explodables: Group<Player>, lookup: Lookup)
    for i, explosion in ipairs(self.on_ground) do

        local collides_with = lookup:collisions_between(explosion.tiles, explodables)
        for _, collide_with in pairs(collides_with) do
            collide_with:stun_for(2)
        end

        explosion:update(dt, blockers, lookup)
        if explosion:is_complete() then
            table.remove(self.on_ground, i)
        end
    end
end

function Lightnings:draw()
    for _, explosion in ipairs(self.on_ground) do
        explosion:draw()
    end
end

return lightnings
