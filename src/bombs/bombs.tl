local explosions = require("bombs.explosions")
local flames = require("bombs.flames")
local closed_tiles = require("closed_tiles")
local animations = require("engine.animations")
local collision = require("engine.collision")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local hitboxes = require("engine.hitboxes")
local physics = require("engine.physics")
local grid_walk = require("grid_walk")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local maps_entities = require("level_layout.maps.entities")
local players = require("players")
local z_index = require("z_index")

local type Animation = animations.Animation
local type ClosedTiles = closed_tiles.ClosedTiles
local type Explodable = require("bombs.explodable")
local type Explosions = explosions.Explosions
local type Entity = require("engine.entity")
local type Kinematic = require("kinematic")
local type Group = collision.Group
local type Player = players.Player
local type ReadableGroup = collision.ReadableGroup
local type Lookup = collision.Lookup
local type ProjectileTrajectory = physics.ProjectileTrajectory
local type Vector = vectors.Vector
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type Goal = maps_entities.Goal
local type ConveyorBelt = maps_entities.ConveyorBelt

-- Bomb --
local BOMB_TIMER_START = 2.5
local SLIDE_SPEED = 120
-- From a bomb's middle to the pixel just past its leading edge.
local PAST_LEADING_EDGE = grid.TILE_SIZE / 2 + 0.5
local GOAL_FIRE = 16
local GOAL_PAIR_FIRE = 14
local bomb_shadow: Image
local bomb_image: Image

local record Bomb is Entity, Kinematic, Explodable
    position: Point
    sliding: boolean
    heading: Vector
    slide_carry: number
    kicker: Player
    timer: number
    range: integer
    hand_back: function()
    animation: Animation
end

function Bomb.new(position: Point, range: integer, hand_back: function()): Bomb
    local self: Bomb = setmetatable({}, {__index = Bomb})
    self.position = position
    self.z_index = z_index.BELOW
    self.sliding = false
    self.heading = vectors.new(0, 0)
    self.slide_carry = 0
    self.kicker = nil
    self.range = range
    self.timer = BOMB_TIMER_START
    self.meets_flame = "ignites"
    self.hand_back = hand_back
    self.animation = animations.new(bomb_image, 16, 0.25)
    return self
end

function Bomb:get_position(): Point
    return self.position
end

function Bomb:clear()
    self.hand_back()
end

function Bomb:hitbox(): Rectangle
    return hitboxes.new_block(self.position):shrink(4)
end

function Bomb:movementbox(): Rectangle
    return hitboxes.new_block(self.position)
end

function Bomb:blow_up(_: number)
    self.timer = 0
end

function Bomb:hit_with_bomb()
    -- Does nothing
end

function Bomb:get_goal(): Goal
    for _, goal in ipairs(map_entities.get_goals()) do
        if self.position:distance_to(goal.position) < 3 then
            return goal
        end
    end

    return nil
end

--- A bomb whose fuse runs out as it slides does not finish its tile first. It
-- goes off where it is, and its explosion takes the tile it is nearest to.
function Bomb:is_complete(): boolean
    if self:get_goal() then
        return true
    end

    return self.timer <= 0
end

function Bomb:draw()
    self.animation:draw(self.position.x, self.position.y)
end

--- A bomb kicked across the line it slides along first jumps to the middle of
-- the tile it is nearest to. One kicked back along its line turns where it is.
function Bomb:kick(heading: Vector, kicker: Player)
    local along_its_line = self.sliding and not self.heading:orthogonal(heading)
    if not along_its_line then
        self.position = grid.snap_to(self.position)
    end
    self.sliding = true
    self.heading = heading
    self.kicker = kicker
end

--- Comes to rest in the middle of the tile it is nearest to, which can lie up to
-- half a tile behind it.
function Bomb:stop()
    self.sliding = false
    self.slide_carry = 0
    self.position = grid.snap_to(self.position)
end

--- A sliding bomb takes the direction of a conveyor belt on the pixel where it
-- is in the middle of the belt's tile, whichever way it came from.
function Bomb:turn_on_belt()
    local function under_bomb(belt: ConveyorBelt): boolean
        return belt.position:equal(self.position)
    end
    local belts = itertools.filter(map_entities.get_conveyor_belts(), under_bomb)
    for _, belt in ipairs(belts) do
        self.heading = belt.direction
    end
end

--- The tile the bomb is sliding into, or the next one when it is in the middle
-- of a tile.
function Bomb:tile_ahead(): integer, integer
    return grid.tile_indices(self.position:move(self.heading:scale(PAST_LEADING_EDGE)))
end

--- The tile next to the one the bomb is nearest to, on the side `heading`
-- points to.
function Bomb:tile_next_to(heading: Vector): integer, integer
    return grid.tile_indices(self.position:move(heading:scale(grid.TILE_SIZE)))
end

--- Whole pixels to slide in a frame of `dt` seconds. What is left of a pixel
-- carries over to the next frame.
function Bomb:pixels_to_slide(dt: number): integer
    local pixels, carry = grid_walk.pixels_this_frame(SLIDE_SPEED, dt, self.slide_carry)
    self.slide_carry = carry
    return pixels
end

function Bomb:slide_a_pixel()
    self.position = self.position:move(self.heading)
end

function Bomb:update(dt: number)
    self.timer = self.timer - dt
    self.animation:update(dt)
end

local record ThrownBomb is Entity
    delegate: Bomb
    target: Point
    trajectory: ProjectileTrajectory
end

function ThrownBomb.new(
    delegate: Bomb,
    target: Point,
    start_height: number,
    throw_height: number,
    throw_time: number
): ThrownBomb
    local self: ThrownBomb = setmetatable({}, {__index = ThrownBomb})
    self.delegate = delegate
    self.z_index = z_index.ABOVE
    self.target = target
    self.trajectory = physics.calc_trajectory(
        start_height, 0, throw_height, throw_time, delegate.position, target
    )
    return self
end

function ThrownBomb:bounce()
    self.target = self:get_position():move(
        self.trajectory:get_direction():scale(grid.TILE_SIZE)
    )
    self.trajectory = physics.calc_trajectory(
        0, 0, grid.TILE_SIZE * 0.8, 0.25, self.delegate.position, self.target
    )
end

function ThrownBomb:hitbox(): Rectangle
    return hitboxes.new_block(self:get_position())
end

function ThrownBomb:get_position(): Point
    return self.delegate.position
end

function ThrownBomb:draw()
    local position = self:get_position()
    lutro.graphics.draw(bomb_shadow, position.x - 1, position.y - 8)

    -- Bomb is drawn in the air
    local draw_position = self.trajectory:in_air_position(position)
    self.delegate.animation:draw(draw_position.x, draw_position.y)
end

function ThrownBomb:has_landed(): boolean
    return self.trajectory:finished()
end

function ThrownBomb:update(dt: number)
    local bomb = self.delegate
    if not self:has_landed() then
        bomb.position = self.trajectory:update(dt, bomb.position)
    end

    if self:has_landed() then
        bomb.position = self.target
    end

    -- Don't update bomb as time should not change
    bomb.animation:update(dt)
end

-- Bombs --
local record Bombs
    on_ground: Group<Bomb>
    in_air: Group<ThrownBomb>
    explosions: Explosions
end

local bombs = {Bomb = Bomb, Bombs = Bombs}

function bombs.load_assets()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    bomb_image = lutro.graphics.newImage("assets/bomb/bomb.png")
end

function bombs.new(silent?: boolean): Bombs
    local self: Bombs = setmetatable({}, {__index = Bombs})
    self.on_ground = collision.new_group()
    self.in_air = collision.new_group()
    self.explosions = explosions.new(silent)
    return self
end

local function no_refund()
end

local function is_occupied_by_bomb(position: Point, existing_bombs: {Entity}): boolean
    for _, existing_bomb in ipairs(existing_bombs) do
        if existing_bomb:get_position():equal(position) then
            return true
        end
    end

    return false
end

function Bombs:place_bomb(player: Player, occupied: {Entity})
    local position = grid.snap_to(player.position)
    if is_occupied_by_bomb(position, occupied) then
        return
    end
    if player.bombs == 0 then
        return
    end

    local hand_back_bomb = function() player.bombs = player.bombs + 1 end
    local bomb = Bomb.new(position, player.fire, hand_back_bomb)
    self.on_ground:add(bomb)
    player.bombs = player.bombs - 1
end

-- No owning player: nothing to refund, nothing to check a bomb count against.
function Bombs:place_static_bomb(position: Point, fire: integer)
    self.on_ground:add(Bomb.new(position, fire, no_refund))
end

function Bombs:throw_bomb(from: Point, to: Point): Bomb
    local bomb = Bomb.new(from, 2, no_refund)
    local thrown = ThrownBomb.new(bomb, to, grid.TILE_SIZE, grid.TILE_SIZE * 2, 0.4)
    self.in_air:add(thrown)
    return bomb
end

function Bombs:throw_existing(bomb: Bomb, to: Point)
    local throw_len = bomb.position:distance_to(to)
    local throw_height = grid.TILE_SIZE + throw_len * 0.1
    local throw_time = 0.20 + 0.025 * throw_len / grid.TILE_SIZE
    self.on_ground:remove(bomb)
    bomb.timer = BOMB_TIMER_START -- Reset when thrown
    local thrown = ThrownBomb.new(bomb, to, 0, throw_height, throw_time)
    self.in_air:add(thrown)
end

local function is_goal_tile(i: integer, j: integer): boolean
    local function on_tile(goal: Goal): boolean
        local goal_i, goal_j = grid.tile_indices(goal.position)
        return goal_i == i and goal_j == j
    end
    return itertools.count(map_entities.get_goals(), on_tile) > 0
end

--- The bomb that has this tile as its nearest, sliding or not.
function Bombs:_bomb_on(i: integer, j: integer, except?: Bomb): Bomb
    local function is_on_tile(bomb: Bomb): boolean
        local bomb_i, bomb_j = grid.tile_indices(bomb.position)
        return bomb ~= except and bomb_i == i and bomb_j == j
    end
    return itertools.filter(itertools.sets_as_list(self.on_ground.set), is_on_tile)[1]
end

--- A football goal lies outside the play area, which is closed, and a bomb may
-- slide into it all the same.
function Bombs:_is_open_to(
    bomb: Bomb, i: integer, j: integer, closed: ClosedTiles
): boolean
    local clear_of_bombs = self:_bomb_on(i, j, bomb) == nil
    return clear_of_bombs and (closed:is_open(i, j) or is_goal_tile(i, j))
end

function Bombs:_kick(bomb: Bomb, heading: Vector, kicker: Player, closed: ClosedTiles)
    local i, j = bomb:tile_next_to(heading)
    if self:_is_open_to(bomb, i, j, closed) then
        bomb:kick(heading, kicker)
    end
end

--- Kicks the bomb on a tile, if there is one and the tile behind it is free.
-- `closed` holds the tiles of everything but bombs that stops a bomb.
function Bombs:kick_bomb_on(
    i: integer, j: integer, heading: Vector, kicker: Player, closed: ClosedTiles
)
    local bomb = self:_bomb_on(i, j)
    if bomb then
        self:_kick(bomb, heading, kicker, closed)
    end
end

function Bombs:stop_kicked_by(player: Player)
    local function kicked_by_player(bomb: Bomb): boolean
        return bomb.sliding and bomb.kicker == player
    end
    local kicked = itertools.filter(
        itertools.sets_as_list(self.on_ground.set), kicked_by_player
    )
    for _, bomb in ipairs(kicked) do
        bomb:stop()
    end
end

--- Slides a kicked bomb a pixel at a time, with the tile ahead tested before
-- each one. A player who steps into that tile while the bomb is between two
-- tiles therefore still stops it.
function Bombs:_slide(bomb: Bomb, dt: number, closed: ClosedTiles)
    for _ = 1, bomb:pixels_to_slide(dt) do
        bomb:turn_on_belt()
        local i, j = bomb:tile_ahead()
        if not self:_is_open_to(bomb, i, j, closed) then
            bomb:stop()
            -- A bomb in the way is kicked on, however many kick items the
            -- kicker has picked up.
            local in_the_way = self:_bomb_on(i, j, bomb)
            if in_the_way then
                self:_kick(in_the_way, bomb.heading, bomb.kicker, closed)
            end
            return
        end
        bomb:slide_a_pixel()
    end
end

function Bombs:update(
    dt: number,
    blockers: ReadableGroup<Explodable>,
    explodables: ReadableGroup<Explodable>,
    closed_to_bombs: ClosedTiles,
    bombs_bounce_on: ReadableGroup<Kinematic>,
    lookup: Lookup
)
    -- Before the bombs, so one that a flame reaches goes off in the same frame.
    self.explosions:update(dt, blockers, explodables, lookup)

    for _, bomb in pairs(self.on_ground.set) do
        bomb:update(dt)
        if bomb.sliding then
            self:_slide(bomb, dt, closed_to_bombs)
        end

        if bomb:is_complete() then
            self.on_ground:remove(bomb)
            bomb.hand_back()
            local goal = bomb:get_goal()
            if not goal then
                self.explosions:place_explosion(bomb.position, bomb.range)
            else
                -- The shorter flame starts as much later as the longer one needs for
                -- its extra tiles, so both are full length, and gone, together.
                self.explosions:place_sustaining_explosion(goal.position, GOAL_FIRE)
                self.explosions:place_sustaining_explosion(
                    goal.pair,
                    GOAL_PAIR_FIRE,
                    flames.growth_time(GOAL_FIRE - GOAL_PAIR_FIRE)
                )
            end
        end
    end

    for _, bomb in pairs(self.in_air.set) do
        bomb:update(dt)
        if bomb:has_landed() then
            local hitting_entities = lookup:collisions_between(
                collision.new_group({bomb}), bombs_bounce_on
            )
            local bomb_bouncing = false
            for _, hitting_entity in pairs(hitting_entities) do
                hitting_entity:hit_with_bomb()
                bomb_bouncing = true
            end

            if
                not grid.area():contains(bomb:hitbox()) and not bomb.delegate:get_goal()
            then
                bomb_bouncing = true
            end

            if bomb_bouncing then
                if grid.outside_visible_area(bomb:hitbox()) then
                    -- Bomb outside seen map, loops around
                    bomb.delegate.position = grid.outside_on_opposite_side(
                        bomb:get_position()
                    )
                    bomb.trajectory:reverse()
                end

                bomb:bounce()
            else
                self.in_air:remove(bomb)
                self.on_ground:add(bomb.delegate)
            end
        end
    end
end

local function draw_bomb_shadow(bomb: Bomb)
    lutro.graphics.draw(bomb_shadow, bomb.position.x - 1, bomb.position.y - 8)
end

function Bombs:draw_on_ground_shadows()
    for _, bomb in pairs(self.on_ground.set) do
        draw_bomb_shadow(bomb)
    end
end

function Bombs:draw_in_air_shadows()
    for _, bomb in pairs(self.in_air.set) do
        draw_bomb_shadow(bomb.delegate)
    end
end

return bombs
