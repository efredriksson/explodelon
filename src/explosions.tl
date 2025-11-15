local animations = require("animations")
local audio = require("audio")
local const = require("const")
local hitboxes = require("hitboxes")
local level_map = require("level_map")
local vectors = require("geometry.vectors")

local END_ANIMATION_DURATION: number = 0.6
local FRAME_DURATION = END_ANIMATION_DURATION / 4

local explosion_end_right_image: Image
local explosion_end_left_image: Image
local explosion_end_top_image: Image
local explosion_end_bottom_image: Image
local explosion_horizontal_image: Image
local explosion_vertical_image: Image
local explosion_center_image: Image
local explosion_small: Source
local explosion_medium: Source
local explosion_large: Source


-- Explosion --

global record ExplosionAnimations
    right_end: Animation
    left_end: Animation
    top_end: Animation
    bottom_end: Animation
    middle_horizontal: Animation
    middle_vertical: Animation
    center: Animation
end

local enum ExplosionTileType
    "center"
    "right"
    "left"
    "up"
    "down"
end

local record ExplosionTile
    position: Point
    reduction: integer
    is_last: boolean
    type: ExplosionTileType
end

function ExplosionTile.new(position: Point, reduction: integer, is_last: boolean, explosion_type: ExplosionTileType): ExplosionTile
    local self: ExplosionTile = setmetatable({}, { __index = ExplosionTile })
    self.position = position
    self.reduction = reduction
    self.is_last = is_last
    self.type = explosion_type
    return self
end

function ExplosionTile:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(self.reduction)
end

global record Explosion
    position: Point
    range: number
    duration: number
    delay: number
    speed: number
    tiles: {ExplosionTile}
    blocked_at: {Point}
    animations: ExplosionAnimations
end

function Explosion.new(position: Point, range: number, delay?: number): Explosion
    local self: Explosion = setmetatable({}, { __index = Explosion })
    self.position = position
    self.blocked_at = {}
    self.range = range
    self.tiles = {}
    self.duration = 0
    self.delay = delay or 0
    self.speed = 28
    self.animations = {
        right_end = animations.new(explosion_end_right_image, 16, 16, FRAME_DURATION, 1),
        left_end = animations.new(explosion_end_left_image, 16, 16, FRAME_DURATION, 1),
        top_end = animations.new(explosion_end_top_image, 16, 16, FRAME_DURATION, 1),
        bottom_end = animations.new(explosion_end_bottom_image, 16, 16, FRAME_DURATION, 1),
        middle_horizontal = animations.new(explosion_horizontal_image, 16, 16, FRAME_DURATION, 1),
        middle_vertical = animations.new(explosion_vertical_image, 16, 16, FRAME_DURATION, 1),
        center = animations.new(explosion_center_image, 16, 16, FRAME_DURATION, 1)
    }

    return self
end

function Explosion:play()
    if self.range <= 3 then
        explosion_small:play()
    elseif self.range <= 5 then
        explosion_medium:play()
    else
        explosion_large:play()
    end
end

function Explosion:get_position(): Point
    return self.position
end

function Explosion:has_reached_max_range(): boolean
    return self.duration >= self.range / self.speed
end

function Explosion:new_tile(position: Point, is_last: boolean, explosion_type: ExplosionTileType): ExplosionTile
    local function tile_reduction(): integer
        local min_reduction = 3
        if not self:has_reached_max_range() then
            return min_reduction
        end
        
        local time_since_max_range = self.duration - self.range / self.speed
        local reduction = (1 + math.floor(time_since_max_range / FRAME_DURATION)) * 2
        return math.max(reduction, min_reduction)
    end
    
    return ExplosionTile.new(position, tile_reduction(), is_last, explosion_type)
end

local enum BlockingResult
    "next"
    "now"
    "nil"
end

local type GetBlocker = function(Point): ExplosionBlocking | nil

local function get_cached_blocker_lookup(blockers: {ExplosionBlocking}): GetBlocker
    local cache: {string: ExplosionBlocking} = {}
    for _, block in ipairs(blockers) do
        cache[tostring(block:get_position())] = block
    end

    local function get_possible_blocker(position: Point): ExplosionBlocking | nil
        return cache[tostring(position)]
    end

    return get_possible_blocker
end


function Explosion:_update_active_tiles(get_possible_blocker: GetBlocker)
    self.tiles = {}

    -- Calculate how far the explosion should expanded
    -- based on time elapsed, capped at max range
    local current_radius = math.floor(math.min(self.duration * self.speed, self.range))

    local function is_blocked(pos: Point): BlockingResult
        -- is out of bounds
        if not level_map.player_area():contains(hitboxes.new_block(pos)) then
            return "now"
        end

        -- Once blocked, always blocked for one instance of explosion
        for _, block_at in ipairs(self.blocked_at) do
            if block_at:equal(pos) then
                return "now"
            end
        end

        local blocker = get_possible_blocker(pos)
        if not blocker is nil then
            if blocker.in_explosion then
                return "next"
            else
                blocker:blow_up()
                table.insert(self.blocked_at, pos)
                return "now"
            end
        end

        return "nil"
    end

    -- Recursively propagates explosion tiles until blocked or max range reached
    local function propagate(
        pos: Point,
        delta: Vector,
        distance_traveled: number,
        explosion_type: ExplosionTileType
    ): {ExplosionTile}
        -- Stop propagation if we've exceeded the max range
        -- or the current explosion radius (based on time)
        if distance_traveled > self.range or distance_traveled > current_radius then
            return {}
        end

        local next_pos = pos:move(delta)

        local blocked = is_blocked(next_pos)
        if blocked == "now" then
            return {}
        elseif blocked == "next" then
            table.insert(self.blocked_at, next_pos:move(delta))
            return {self:new_tile(next_pos, true, explosion_type)}
        end

        local remaining_tiles = propagate(next_pos, delta, distance_traveled + 1, explosion_type)
        local is_last = #remaining_tiles == 0

        local tile = self:new_tile(next_pos, is_last, explosion_type)

        table.insert(remaining_tiles, tile)
        return remaining_tiles
    end

    -- Center tile
    table.insert(self.tiles, self:new_tile(self.position, false, "center"))

    local directions: {ExplosionTileType: Vector} = {
        right = vectors.new(1, 0),
        left = vectors.new(-1, 0),
        down = vectors.new(0, 1),
        up = vectors.new(0, -1),
    }

    -- Propagate in all four directions
    for direction, delta in pairs(directions) do
        for _, tile in ipairs(propagate(self.position, delta:scale(const.BLOCK_SIZE), 1, direction)) do
            table.insert(self.tiles, tile)
        end
    end
end

function Explosion:get_tile_animation(tile: ExplosionTile): Animation
    if tile.type == "center" then
        return self.animations.center
    end

    if tile.is_last then
        if tile.type == "right" then return self.animations.right_end end
        if tile.type == "left" then return self.animations.left_end end
        if tile.type == "up" then return self.animations.top_end end
        if tile.type == "down" then return self.animations.bottom_end end
    end

    if tile.type == "right" or tile.type == "left" then
        return self.animations.middle_horizontal
    end

    return self.animations.middle_vertical
end

function Explosion:collides_with(explodable: Explodable): boolean
    for _, tile in ipairs(self.tiles) do
        if explodable:hitbox():overlap(tile:hitbox()) then
            return true
        end
    end

    return false
end

function Explosion:is_complete(): boolean
    return self.animations.center.loops > 0
end

function Explosion:draw()
    for _, tile in ipairs(self.tiles) do
        local animation = self:get_tile_animation(tile)
        animation:draw(tile.position.x, tile.position.y)
        hitboxes.draw(tile:hitbox())
    end
end

function Explosion:update_end_animation(dt: number)
    self.animations.right_end:update(dt)
    self.animations.left_end:update(dt)
    self.animations.top_end:update(dt)
    self.animations.bottom_end:update(dt)
    self.animations.middle_horizontal:update(dt)
    self.animations.middle_vertical:update(dt)
    self.animations.center:update(dt)
end

function Explosion:update(dt: number, get_possible_blocker: GetBlocker)
    if self.delay > 0 then
        self.delay = self.delay - dt
        return
    end

    self.duration = self.duration + dt
    self:_update_active_tiles(get_possible_blocker)

    if self:has_reached_max_range() then
        self:update_end_animation(dt)
    end
end

-- Explosions --
global record Explosions
    on_ground: {Explosion}
end

local explosions = {}

function explosions.load_assets()
    local function get_explosion_image(tile: string): Image
        return lutro.graphics.newImage("assets/bomb/explosion/explosion_" .. tile .. ".png")
    end

    explosion_end_right_image = get_explosion_image("end_right")
    explosion_end_left_image = get_explosion_image("end_left")
    explosion_end_top_image = get_explosion_image("end_top")
    explosion_end_bottom_image = get_explosion_image("end_bottom")
    explosion_horizontal_image = get_explosion_image("horizontal")
    explosion_vertical_image = get_explosion_image("vertical")
    explosion_center_image = get_explosion_image("center")

    local function get_explosion_audio(size: string): Source
        local explosion_audio = audio.new_source_pool("assets/bomb/explosion/" .. size .. ".wav", "static", 5)
        explosion_audio:setVolume(0.4)
        explosion_audio:setPitch(0.25)
        return explosion_audio
    end

    explosion_small = get_explosion_audio("small")
    explosion_medium = get_explosion_audio("medium")
    explosion_large = get_explosion_audio("large")
end

function explosions.new(): Explosions
   local self: Explosions = setmetatable({}, { __index = Explosions })
   self.on_ground = {}
   return self
end

function Explosions:place_explosion(position: Point, range: number, delay?: number)
    local explosion = Explosion.new(position, range, delay)
    explosion:play()
    table.insert(self.on_ground, explosion)
end

function Explosions:update(dt: number, blockers: {ExplosionBlocking}, explodables: {Explodable})
    -- Create a lookup of possible blockers given position, avoids getting
    -- O(n^2) due to nested loops checking all possible combinations.
    local get_possible_blocker = get_cached_blocker_lookup(blockers)

    for i, explosion in ipairs(self.on_ground) do
        explosion:update(dt, get_possible_blocker)

        for _, explodable in ipairs(explodables) do
            if explosion:collides_with(explodable) then
                explodable:blow_up()
            end
        end

        if explosion:is_complete() then
            table.remove(self.on_ground, i)
        end
    end
end

function Explosions:draw()
    for _, explosion in ipairs(self.on_ground) do
        explosion:draw()
    end
end

return explosions
