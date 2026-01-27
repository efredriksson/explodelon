local animations = require("engine.animations")
local collision = require("engine.collision")
local maps_entities = require("level_layout.maps.entities")
local explosions = require("bombs.explosions")
local map_entities = require("level_layout.map_entities")
local grid = require("level_layout.grid")
local hitboxes = require("engine.hitboxes")
local itertools = require("itertools")
local logger = require("engine.logger")
local physics = require("engine.physics")
local players = require("players")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")

local type Animation = animations.Animation
local type Explodable = require("bombs.explodable")
local type Explosions = explosions.Explosions
local type Kinematic = require("kinematic")
local type Entity = require("engine.entity")
local type Player = players.Player
local type Group = collision.Group
local type Lookup = collision.Lookup
local type ProjectileTrajectory = physics.ProjectileTrajectory
local type Vector = vectors.Vector
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type Goal = maps_entities.Goal
local type ConveyorBelt = maps_entities.ConveyorBelt

-- Bomb --

local BOMB_TIMER_START = 2.5
local bomb_shadow: Image
local bomb_image: Image

local record Bomb is Entity, Kinematic, Explodable
    position: Point
    velocity: Vector
    timer: number
    range: number
    hand_back: function()
    has_been_kicked: boolean
    stopping: boolean
    animation: Animation
end

function Bomb.new(position: Point, range: integer, hand_back: function()): Bomb
   local self: Bomb = setmetatable({}, { __index = Bomb })
   self.position = position
   self.velocity = vectors.new(0, 0)
   self.range = range
   self.timer = BOMB_TIMER_START
   self.hand_back = hand_back
   self.has_been_kicked = false
   self.stopping = false
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

function Bomb:blow_up()
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

function Bomb:is_complete(): boolean
    if self:get_goal() then
        return true
    end

    return self.timer <= 0 and self.position:equal(grid.snap_to(self.position))
end

function Bomb:draw()
    self.animation:draw(self.position.x, self.position.y)
end

function Bomb:_trigger_belt(direction?: Vector): ConveyorBelt | nil
    local bomb_move_dir = direction or self.velocity

    local function bomb_on(belt: ConveyorBelt): boolean
        return belt:get_hitbox():overlap(self:movementbox())
    end
    local belts = itertools.filter(map_entities.get_conveyor_belts(), bomb_on)
    for _, belt in ipairs(belts) do
        if self.position:distance_to(grid.snap_to(self.position)) <= 3 then
            local snap_pos = grid.snap_to(self.position)
            if snap_pos:equal(belt.position) and not belt.direction:same_direction(bomb_move_dir) then
                return belt
            end
        end
    end
end

local function moving_outside_of_map(test_hitbox: Rectangle): boolean
    local bomb_in_goal = false
    for _, goal in ipairs(map_entities.get_goals()) do
        if test_hitbox:overlap(goal:get_hitbox()) then
            bomb_in_goal = true
        end
    end

    return not grid.area():contains(test_hitbox) and not bomb_in_goal
end

local function moving_into_new_block(movementbox: Rectangle, direction: Vector): Rectangle | nil
    local snaps_to = grid.snap_to(movementbox:top_left())
    local new_movementbox = movementbox:shift(direction)

    for i=-1, 1 do
        for j=-1, 1 do
            local close_block = hitboxes.new_block(points.new(
                snaps_to.x + i * grid.TILE_SIZE,
                snaps_to.y + j * grid.TILE_SIZE
            ))
            if new_movementbox:overlap(close_block) and not movementbox:overlap(close_block) then
                return close_block
            end
        end
    end

    return nil
end

function Bomb:kick(direction: Vector)
    local slide_speed = 120
    self.velocity = direction:scale(slide_speed)
    self.has_been_kicked = true
end

local record CanMoveBomb
    yes: boolean
    new_position: Point
    in_direction: Vector
    will_hit: Bomb | nil
    should_stop: boolean
end

function CanMoveBomb.new(new_position: Point, in_direction: Vector): CanMoveBomb
   local self: CanMoveBomb = setmetatable({}, { __index = CanMoveBomb })
   self.yes = true
   self.new_position = new_position
   self.in_direction = in_direction
   self.will_hit = nil
   self.should_stop = false
   return self
end

function CanMoveBomb:no(): CanMoveBomb
   self.yes = false
   return self
end

function Bomb:can_move(direction: Vector, occupies: Group<Kinematic>, players_: Group<Player>, bombs: Group<Bomb>, lookup: Lookup, call_level?: integer): CanMoveBomb    
    local function not_this_bomb(occupied: Kinematic): boolean
        return occupied ~= self
    end

    local test_hitbox = self:movementbox():shift(direction)
    local old_hitbox = self:movementbox()
    local can_move_bomb = CanMoveBomb.new(test_hitbox:top_left(), direction:normalize())
    local close_occupies = lookup:in_box_and_group(old_hitbox:expand(grid.TILE_SIZE), occupies)
    local close_players = lookup:in_box_and_group(old_hitbox:expand(grid.TILE_SIZE), players_)
    local close_bombs = lookup:in_box_and_group(old_hitbox:expand(grid.TILE_SIZE), bombs)
    close_bombs = itertools.filter(close_bombs, not_this_bomb)
    local close_interacts: {Kinematic} = itertools.combine(close_bombs, close_players)

    local next_call_level = (call_level or 1) + 1
    if next_call_level > 3 then
        -- Stop when called recursive 3 times, no more chain reactions should be possible.
        logger.info("Recursive bomb can move calls, aborting")
        return can_move_bomb:no()
    end

    local belt_trigger = self:_trigger_belt(direction)
    if not belt_trigger is nil then
        direction = belt_trigger.direction:scale(direction:length())
        can_move_bomb.in_direction = direction:normalize()
    end

    if moving_outside_of_map(test_hitbox) then
        return can_move_bomb:no()
    end

    local function overlaps_significantly(entity: Kinematic, hitbox: Rectangle): boolean
        return entity:hitbox():overlap(hitbox:shrink(3))
    end

    local function overlaps_entity_significantly(hitbox: Rectangle, entities: {Kinematic}): boolean
        for _, occupied in ipairs(entities) do
            if overlaps_significantly(occupied, hitbox) then
                return true
            end
        end
        return false
    end

    local will_go_into_entity = overlaps_entity_significantly(
        test_hitbox, itertools.combine(close_occupies, close_interacts)
    )

    if self.velocity:length() > 0 and not self.velocity:same_direction(direction) then
        -- Bomb is getting kicked from the side while moving. If this happen and
        -- the bomb would otherwise have moved inot new block tile, then we help the
        -- side kick by snapping the projected position/hitbox to corridor. This means
        -- a side kick can be done without things aligning exactly!
        local mock_dt = 1/60 -- TODO: Need to pass in 'dt' in here to properly calculate this
        local passing = moving_into_new_block(self:movementbox(), self.velocity:scale(mock_dt))
        if self.velocity:orthogonal(direction) and passing then
            if direction.x == 0 then
                test_hitbox.x = grid.snap_to_x(test_hitbox.x)
            elseif direction.y == 0 then
                test_hitbox.y = grid.snap_to_y(test_hitbox.y)
            end

            can_move_bomb.new_position = test_hitbox:top_left()
        end

        -- The bomb is moving and is getting kicked in other direction. In this case
        -- we want to make sure it is not moving into something. Regardless if it is
        -- not technically moving into a new block. Consider for example two players
        -- that are both kicking the bomb from opposite sides.
        if will_go_into_entity then
            return can_move_bomb:no()
        end
    end

    for _, bomb in ipairs(close_bombs) do
        if overlaps_significantly(bomb, test_hitbox) then
            if bomb:can_move(direction, occupies, players_, bombs, lookup, next_call_level).yes then
                can_move_bomb.will_hit = bomb
            end
        end
    end

    if self.velocity:length() > 0 and will_go_into_entity then
        -- If the bomb is already going into a new block we let it.
        -- But, if there is some collision this will be the last block
        -- it enters before stopping.
        can_move_bomb.should_stop = true
    end

    local new_block = moving_into_new_block(self:movementbox(), direction)
    if not new_block is nil then
        if self.stopping then
            return can_move_bomb:no()
        end
        
        for _, occupied in ipairs(close_occupies) do
            if occupied:movementbox():overlap(test_hitbox) then
                return can_move_bomb:no()
            end
        end

        for _, bomb in ipairs(close_bombs) do
            if overlaps_significantly(bomb, new_block) then
                if bomb:can_move(direction, occupies, players_, bombs, lookup, next_call_level).yes then
                    can_move_bomb.will_hit = bomb
                end
            end
        end

        if overlaps_entity_significantly(new_block, close_interacts) then
            return can_move_bomb:no()
        end
    end

    return can_move_bomb
end

function Bomb:update(dt: number, occupies: Group<Kinematic>, players_: Group<Player>, bombs: Group<Bomb>, lookup: Lookup)
    self.timer = self.timer - dt
    
    if self.velocity:length() > 0 then
        local belt_trigger = self:_trigger_belt()
        if not belt_trigger is nil then
            self.position = belt_trigger.position
            self.velocity = belt_trigger.direction:scale(self.velocity:length())
        end

        local dx = self.velocity:scale(dt)
        local new_block = moving_into_new_block(self:movementbox(), dx)
        local can_move = self:can_move(dx, occupies, players_, bombs, lookup)
        if self.timer <= 0 and new_block then
            -- If bomb timer is up and if trying to enter a new block snap to grid instead.
            -- This is to explode bomb on the grid. Bomb can slide to next intersection!
            self.position = grid.snap_to(self.position)
        elseif can_move.yes then
            self.position = can_move.new_position
        else
            -- If bomb can't move stop it and snap to grid
            self.velocity = vectors.new(0, 0)
            self.position = grid.snap_to(self.position)
            self.stopping = false
        end

        local bomb_hit = can_move.will_hit
        if not bomb_hit is nil then
            bomb_hit:kick(dx:normalize())
        end
        if can_move.should_stop then
            self.stopping = true
        end
    end

    self.animation:update(dt)
end

local record ThrownBomb is Entity
    delegate: Bomb
    target: Point
    trajectory: ProjectileTrajectory
end

function ThrownBomb.new(delegate: Bomb, target: Point, start_height: number, throw_height: number, throw_time: number): ThrownBomb
    local self: ThrownBomb = setmetatable({}, { __index = ThrownBomb })
    self.delegate = delegate
    self.target = target
    self.trajectory = physics.calc_trajectory(
        start_height, 0, throw_height, throw_time, delegate.position, target
    )
    return self
end

function ThrownBomb:bounce()
    self.target = self:get_position():move(self.trajectory:get_direction():scale(grid.TILE_SIZE))
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
    on_ground: {Bomb}
    in_air: {ThrownBomb}
    explosions: Explosions
end

local bombs = {Bomb = Bomb, Bombs = Bombs}

function bombs.load_assets()
    bomb_shadow = lutro.graphics.newImage("assets/items/shadow.png")
    bomb_image = lutro.graphics.newImage("assets/bomb/bomb.png")
end

function bombs.new(): Bombs
    local self: Bombs = setmetatable({}, { __index = Bombs })
    self.on_ground = {}
    self.in_air = {}
    self.explosions = explosions.new()
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
    table.insert(self.on_ground, bomb)
    player.bombs = player.bombs - 1
end

function Bombs:throw_bomb(from: Point, to: Point): Bomb
    local bomb = Bomb.new(from, 2, function() end)
    local thrown = ThrownBomb.new(bomb, to, grid.TILE_SIZE, grid.TILE_SIZE * 2, 0.4)
    table.insert(self.in_air, thrown)
    return bomb
end

function Bombs:throw_existing(bomb: Bomb, to: Point)
    local throw_len = bomb.position:distance_to(to)
    local throw_height = grid.TILE_SIZE + throw_len * 0.1
    local throw_time = 0.20 + 0.025 * throw_len / grid.TILE_SIZE
    for i, on_ground in ipairs(self.on_ground) do
        if on_ground == bomb then
            table.remove(self.on_ground, i)
            bomb.timer = BOMB_TIMER_START -- Reset when thrown
            local thrown = ThrownBomb.new(bomb, to, 0, throw_height, throw_time)
            table.insert(self.in_air, thrown)
            return
        end
    end
end

function Bombs:update(
    dt: number,
    blockers: Group<Explodable>,
    explodables: Group<Explodable>,
    occupies: Group<Kinematic>,
    players_: Group<Player>,
    bombs_: Group<Bomb>,
    bombs_bounce_on: Group<Kinematic>,
    lookup: Lookup
)
    for i = #self.on_ground, 1, -1 do
        local bomb = self.on_ground[i]
        bomb:update(dt, occupies, players_, bombs_, lookup)

        if bomb:is_complete() then
            table.remove(self.on_ground, i)
            bomb.hand_back()
            local goal = bomb:get_goal()
            if not goal then
                self.explosions:place_explosion(bomb.position, bomb.range)
            else
                self.explosions:place_explosion(goal.position, 16)
                self.explosions:place_explosion(goal.pair, 14, 0.072)
            end
        end
    end

    for i, bomb in ipairs(self.in_air) do
        bomb:update(dt)
        if bomb:has_landed() then
            local hitting_entities = lookup:collisions_between({bomb}, bombs_bounce_on)
            local bomb_bouncing = false
            for _, hitting_entity in pairs(hitting_entities) do
                hitting_entity:hit_with_bomb()
                bomb_bouncing = true
            end

            if not grid.area():contains(bomb:hitbox()) and not bomb.delegate:get_goal() then
                bomb_bouncing = true
            end
            
            if bomb_bouncing then
                if grid.outside_visible_area(bomb:hitbox()) then
                    -- Bomb outside seen map, loops around
                    bomb.delegate.position = grid.outside_on_opposite_side(bomb:get_position())
                    bomb.trajectory:reverse()
                end

                bomb:bounce()
            else
                table.remove(self.in_air, i)
                table.insert(self.on_ground, bomb.delegate)
            end
        end
    end

    self.explosions:update(dt, blockers, explodables, lookup)
end

local function draw_bomb_shadow(bomb: Bomb)
    lutro.graphics.draw(bomb_shadow, bomb.position.x - 1, bomb.position.y - 8)
end

function Bombs:draw_on_ground_shadows()
    for _, bomb in ipairs(self.on_ground) do
        draw_bomb_shadow(bomb)
    end
end

function Bombs:draw_in_air_shadows()
    for _, bomb in ipairs(self.in_air) do
        draw_bomb_shadow(bomb.delegate)
    end
end

return bombs
