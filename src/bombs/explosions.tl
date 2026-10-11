local flames = require("bombs.flames")
local animations = require("engine.animations")
local audio = require("engine.audio")
local collision = require("engine.collision")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local hitboxes = require("engine.hitboxes")
local images = require("engine.images")
local itertools = require("itertools")
local grid = require("level_layout.grid")

local type Animation = animations.Animation
local type Direction = vectors.Direction
local type Explodable = require("bombs.explodable")
local type Explosion = flames.Explosion
local type Flame = flames.Flame
local type Lookup = collision.Lookup
local type Meeting = flames.Meeting
local type Meets = flames.Meets
local type Point = points.Point
local type ReadableGroup = collision.ReadableGroup

-- Flames are blended over the floor at 24/32.
local FLAME_ALPHA = 191
local BURST_WIDTH = 24
-- A burst frame is larger than the tile it is drawn over.
local BURST_OFFSET = vectors.new(-4, -8)
-- Wider than any arena, so a tile outside the grid, such as a football goal,
-- never shares a key with one inside it.
local TILE_KEY_STRIDE = 1024
-- Ages are sums of steps, so two explosions that drew a tile at the same moment
-- can differ by a rounding error. Within this they drew together.
local DRAWN_TOGETHER = 0.001

local center_image: Image
local tip_images: {Direction: Image}
local middle_images: {Direction: Image}
local burst_image: Image
local explosion_small: Source
local explosion_medium: Source
local explosion_large: Source

--- Every flame piece in each of its phases, thick to thin, and the cracking bomb.
local record FlameArt
    center: {Animation}
    tip: {Direction: {Animation}}
    middle: {Direction: {Animation}}
    burst: {Animation}
end

local function frozen_frames(image: Image, width: integer, count: integer): {Animation}
    local frames: {Animation} = {}
    for frame = 1, count do
        frames[frame] = animations.new_frozen(image, width, frame)
    end
    return frames
end

local function phases_by_direction(
    by_direction: {Direction: Image}
): {Direction: {Animation}}
    local phases: {Direction: {Animation}} = {}
    for direction, image in pairs(by_direction) do
        phases[direction] = frozen_frames(image, grid.TILE_SIZE, flames.PHASES)
    end
    return phases
end

function FlameArt.new(): FlameArt
    local self: FlameArt = setmetatable({}, {__index = FlameArt})
    self.center = frozen_frames(center_image, grid.TILE_SIZE, flames.PHASES)
    self.tip = phases_by_direction(tip_images)
    self.middle = phases_by_direction(middle_images)
    self.burst = frozen_frames(burst_image, BURST_WIDTH, flames.BURST_STAGES)
    return self
end

function FlameArt:piece(flame: Flame): Animation
    if flame.shape == "center" then
        return self.center[flame.phase]
    elseif flame.shape == "tip" then
        return self.tip[flame.direction][flame.phase]
    end
    return self.middle[flame.direction][flame.phase]
end

local record Explosions
    on_ground: {Explosion}
    burning: {Flame}
    art: FlameArt
    silent: boolean
end

local explosions = {Explosions = Explosions}

function explosions.load_assets()
    local function flame_image(piece: string): Image
        local image = lutro.graphics.newImage(
            "assets/bomb/explosion/explosion_" .. piece .. ".png"
        )
        images.set_alpha(image, FLAME_ALPHA)
        return image
    end

    center_image = flame_image("center")
    tip_images = {
        right = flame_image("end_right"),
        left = flame_image("end_left"),
        up = flame_image("end_top"),
        down = flame_image("end_bottom"),
    }
    local horizontal_image = flame_image("horizontal")
    local vertical_image = flame_image("vertical")
    middle_images = {
        right = horizontal_image,
        left = horizontal_image,
        up = vertical_image,
        down = vertical_image,
    }
    burst_image = lutro.graphics.newImage("assets/bomb/explosion/burst.png")

    local function get_explosion_audio(size: string): Source
        local explosion_audio = audio.new_source_pool(
            "assets/bomb/explosion/" .. size .. ".wav", "static", 5
        )
        explosion_audio:setVolume(0.4)
        explosion_audio:setPitch(0.25)
        return explosion_audio
    end

    explosion_small = get_explosion_audio("small")
    explosion_medium = get_explosion_audio("medium")
    explosion_large = get_explosion_audio("large")
end

function explosions.new(silent?: boolean): Explosions
    local self: Explosions = setmetatable({}, {__index = Explosions})
    self.on_ground = {}
    self.burning = {}
    self.art = FlameArt.new()
    self.silent = silent or false
    return self
end

local function play_sound(range: number)
    if range <= 3 then
        explosion_small:play()
    elseif range <= 5 then
        explosion_medium:play()
    else
        explosion_large:play()
    end
end

function Explosions:_place(explosion: Explosion)
    local function sustains_it(other: Explosion): boolean
        return other.sustains and other:has_in_line_of_fire(explosion.i, explosion.j)
    end
    for _, sustaining in ipairs(itertools.filter(self.on_ground, sustains_it)) do
        explosion:burn_as_long_as(sustaining)
    end
    table.insert(self.on_ground, explosion)
    if not self.silent then
        play_sound(explosion.fire)
    end
end

function Explosions:place_explosion(position: Point, range: integer)
    local i, j = grid.tile_indices(position)
    self:_place(flames.new(i, j, range))
end

--- For an explosion much bigger than a bomb's. A bomb it set off would burn out
-- long before it and leave a hole in its flame, so explosions in its line of
-- fire last until it fades.
function Explosions:place_sustaining_explosion(
    position: Point, range: integer, seconds_later?: number
)
    local i, j = grid.tile_indices(position)
    self:_place(flames.new_sustaining(i, j, range, seconds_later))
end

--- Members of a group standing on a tile. Something between two tiles, such as
-- a walking player or a sliding bomb, stands on the tile it is nearest to.
local function standing_on(
    i: integer, j: integer, group: ReadableGroup<Explodable>, lookup: Lookup
): {Explodable}
    local overlapping = lookup:in_box_and_group(grid.get_tile(i, j), group)
    if #overlapping == 0 then
        return overlapping
    end
    local function is_nearest_to_tile(explodable: Explodable): boolean
        local nearest_i, nearest_j = grid.tile_indices(explodable:get_position())
        return nearest_i == i and nearest_j == j
    end
    -- The lookup lists something once for every lookup cell it overlaps.
    return itertools.filter(itertools.unique(overlapping), is_nearest_to_tile)
end

local function blocks_flame(blocker: Explodable): boolean
    return blocker.meets_flame == "blocks"
end

local function ignites(blocker: Explodable): boolean
    return blocker.meets_flame == "ignites"
end

local function blow_up(explodable: Explodable)
    explodable:blow_up(explodable:hitbox():area())
end

function Explosions:_has_other_center_at(
    i: integer, j: integer, explosion: Explosion
): boolean
    local function is_other_center_here(other: Explosion): boolean
        return other ~= explosion
            and other.i == i
            and other.j == j
            and other:is_burning()
    end
    return itertools.count(self.on_ground, is_other_center_here) > 0
end

--- What an arm of this explosion meets as it reaches a tile; what catches fire
-- there is set alight. A tile can hold several things, such as a burning soft
-- block with its item already under it; the one that stops the flame soonest
-- decides.
function Explosions:_meets_for(
    explosion: Explosion, blockers: ReadableGroup<Explodable>, lookup: Lookup
): Meets
    local function meets(i: integer, j: integer): Meeting
        if not grid.has_tile(i, j) then
            return "capped_before"
        end
        local on_tile = standing_on(i, j, blockers, lookup)
        if itertools.count(on_tile, blocks_flame) > 0 then
            return "capped_before"
        end
        local set_alight = itertools.filter(on_tile, ignites)
        for _, blocker in ipairs(set_alight) do
            blow_up(blocker)
        end
        if #set_alight > 0 or self:_has_other_center_at(i, j, explosion) then
            return "flat_before"
        elseif #on_tile > 0 then
            return "ends_on"
        end
        return "passes"
    end
    return meets
end

local function shows_over(flame: Flame, other: Flame): boolean
    if other.shape == "center" then
        return false
    end
    return flame.shape == "center"
        or flame.time_since_drawn <= other.time_since_drawn + DRAWN_TOGETHER
end

--- One flame per burning tile. Explosions come oldest first, so where two drew a
-- shared tile together the younger one shows.
local function lay_out(on_ground: {Explosion}): {Flame}
    local by_tile: {integer: Flame} = {}
    for _, explosion in ipairs(on_ground) do
        for _, flame in ipairs(explosion:flames()) do
            local tile = flame.j * TILE_KEY_STRIDE + flame.i
            local other = by_tile[tile]
            if other == nil then
                by_tile[tile] = flame
            elseif shows_over(flame, other) then
                flame.deadly = flame.deadly or other.deadly
                by_tile[tile] = flame
            else
                other.deadly = other.deadly or flame.deadly
            end
        end
    end
    return itertools.sets_as_list(by_tile)
end

function Explosions:_blow_up_standing_in_flames(
    explodables: ReadableGroup<Explodable>, lookup: Lookup
)
    local function is_deadly(flame: Flame): boolean
        return flame.deadly
    end
    for _, flame in ipairs(itertools.filter(self.burning, is_deadly)) do
        local standing = standing_on(flame.i, flame.j, explodables, lookup)
        for _, explodable in ipairs(standing) do
            blow_up(explodable)
        end
    end
end

function Explosions:update(
    dt: number,
    blockers: ReadableGroup<Explodable>,
    explodables: ReadableGroup<Explodable>,
    lookup: Lookup
)
    if #self.on_ground == 0 then
        return
    end
    for index = #self.on_ground, 1, -1 do
        local explosion = self.on_ground[index]
        explosion:advance(dt, self:_meets_for(explosion, blockers, lookup))
        if explosion:is_over() then
            table.remove(self.on_ground, index)
        end
    end
    self.burning = lay_out(self.on_ground)
    self:_blow_up_standing_in_flames(explodables, lookup)
end

function Explosions:draw()
    for _, flame in ipairs(self.burning) do
        local tile = grid.get_tile(flame.i, flame.j)
        self.art:piece(flame):draw(tile.x, tile.y)
        if flame.deadly then
            hitboxes.draw(tile)
        end
    end
    for _, explosion in ipairs(self.on_ground) do
        local stage = explosion:burst_stage()
        if stage > 0 then
            local position = grid.get_tile_position(explosion.i, explosion.j):move(
                BURST_OFFSET
            )
            self.art.burst[stage]:draw(position.x, position.y)
        end
    end
end

return explosions
