require("animation")
require("player")
require("level_map")

local END_ANIMATION_DURATION: number = 0.6

local explosion_end_right_image: Image
local explosion_end_left_image: Image
local explosion_end_top_image: Image
local explosion_end_bottom_image: Image
local explosion_horizontal_image: Image
local explosion_vertical_image: Image
local explosion_center_image: Image

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
    rect: Rectangle
    is_last: boolean
    type: ExplosionTileType
end

function ExplosionTile.new(rect: Rectangle, is_last: boolean, explosion_type: ExplosionTileType): ExplosionTile
    local self: ExplosionTile = setmetatable({}, { __index = ExplosionTile })
    self.rect = rect
    self.is_last = is_last
    self.type = explosion_type
    return self
end

global record Explosion is Entity
    range: number
    duration: number
    speed: number
    animations: ExplosionAnimations
end

function Explosion.new(position: Point, range: number): Explosion
   local self: Explosion = setmetatable({}, { __index = Explosion })
   self.position = position
   self.range = range
   self.duration = 0
   self.speed = 28
   local frame_duration = END_ANIMATION_DURATION / 4
   self.animations = {
       right_end = Animation.new(explosion_end_right_image, 16, 16, frame_duration, 1),
       left_end = Animation.new(explosion_end_left_image, 16, 16, frame_duration, 1),
       top_end = Animation.new(explosion_end_top_image, 16, 16, frame_duration, 1),
       bottom_end = Animation.new(explosion_end_bottom_image, 16, 16, frame_duration, 1),
       middle_horizontal = Animation.new(explosion_horizontal_image, 16, 16, frame_duration, 1),
       middle_vertical = Animation.new(explosion_vertical_image, 16, 16, frame_duration, 1),
       center = Animation.new(explosion_center_image, 16, 16, frame_duration, 1)
   }

   return self
end

function Explosion:get_active_tiles(): {ExplosionTile}
    local tiles: {ExplosionTile} = {}

    -- Calculate how far the explosion should expanded
    -- based on time elapsed, capped at max range
    local current_radius = math.floor(math.min(self.duration * self.speed, self.range))

    local function is_blocked(pos: Point): boolean
        -- is out of bounds
        if pos.x < PLAYER_AREA.x or pos.x >= PLAYER_AREA.x + PLAYER_AREA.width or
           pos.y < PLAYER_AREA.y or pos.y >= PLAYER_AREA.y + PLAYER_AREA.height then
            return true
        end

        -- is hard block
        for _, block in ipairs(HARD_BLOCKS) do
            if pos:equal(block:top_left()) then
                return true
            end
        end

        return false
    end

    -- Recursively propagates explosion tiles until blocked or max range reached
    local function propagate(
        pos: Point,
        dx: number,
        dy: number,
        distance_traveled: number,
        explosion_type: ExplosionTileType
    ): {ExplosionTile}
        -- Stop propagation if we've exceeded the max range
        -- or the current explosion radius (based on time)
        if distance_traveled > self.range or distance_traveled > current_radius then
            return {}
        end

        local next_pos = Point.new(pos.x + dx * BLOCK_SIZE, pos.y + dy * BLOCK_SIZE)

        if is_blocked(next_pos) then
            return {}
        end

        local remaining_tiles = propagate(next_pos, dx, dy, distance_traveled + 1, explosion_type)
        local is_last = #remaining_tiles == 0

        local tile = ExplosionTile.new(new_hit_box(next_pos), is_last, explosion_type)

        table.insert(remaining_tiles, tile)
        return remaining_tiles
    end

    -- Center tile
    table.insert(tiles, ExplosionTile.new(new_hit_box(self.position), false, "center"))

    -- Propagate in all four directions
    for _, tile in ipairs(propagate(self.position, 1, 0, 1, "right")) do
        table.insert(tiles, tile)
    end
    for _, tile in ipairs(propagate(self.position, -1, 0, 1, "left")) do
        table.insert(tiles, tile)
    end
    for _, tile in ipairs(propagate(self.position, 0, 1, 1, "down")) do
        table.insert(tiles, tile)
    end
    for _, tile in ipairs(propagate(self.position, 0, -1, 1, "up")) do
        table.insert(tiles, tile)
    end

    return tiles
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

function Explosion:has_reached_max_range(): boolean
    return self.duration >= self.range / self.speed
end

function Explosion:collides_with(position: Point): boolean
    local hitbox = new_hit_box(position)
    local tiles = self:get_active_tiles()

    for _, tile in ipairs(tiles) do
        if hitbox:overlap(tile.rect:shrink(2)) then
            return true
        end
    end

    return false
end

function Explosion:is_complete(): boolean
    return self.animations.center.loops > 0
end

function Explosion:draw()
    local tiles = self:get_active_tiles()

    for _, tile in ipairs(tiles) do
        local animation = self:get_tile_animation(tile)
        animation:draw(tile.rect.x, tile.rect.y)
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

function Explosion:update(dt: number)
    self.duration = self.duration + dt

    if self:has_reached_max_range() then
        self:update_end_animation(dt)
    end
end

-- Explosions --
global record Explosions
    on_ground: {Explosion}
end

function Explosions:load()
    explosion_end_right_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_end_right.png")
    explosion_end_left_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_end_left.png")
    explosion_end_top_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_end_top.png")
    explosion_end_bottom_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_end_bottom.png")
    explosion_horizontal_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_horizontal.png")
    explosion_vertical_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_vertical.png")
    explosion_center_image = lutro.graphics.newImage("assets/bomb/explosion/explosion_center.png")
end

function Explosions.new(): Explosions
   local self: Explosions = setmetatable({}, { __index = Explosions })
   self.on_ground = {}
   return self
end

function Explosions:place_explosion(position: Point, range: number)
    local explosion = Explosion.new(position, range)
    table.insert(self.on_ground, explosion)
end

function Explosions:update(dt: number, players: {Player})
    for i, explosion in ipairs(self.on_ground) do
        explosion:update(dt)

        for _, player in ipairs(players) do
            if explosion:collides_with(player.position) then
                player:kill()
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