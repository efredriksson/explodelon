-- The chaser seals the victim into the SE corner with dripped bombs.

local characters = require("characters")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local players = require("players")
local choreography = require("preview.choreography")
local drones = require("preview.drones")
local scenery = require("preview.scenery")

local type CharacterName = characters.CharacterName
local type Choreography = choreography.Choreography
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point
local type Scenery = scenery.Scenery
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type Stage = choreography.Stage

local soft_block_at = scenery.soft_block_at
local item_at = scenery.item_at

local VICTIM_START = grid.get_tile_position(6, 5)
local CORNER_REST = grid.get_tile_position(16, 10)

local BYSTANDER_START = grid.get_tile_position(16, 1)
local BYSTANDER_REST = grid.get_tile_position(8, 4)

local CHASER_START = grid.get_tile_position(7, 4)
local HERD_JOIN = grid.get_tile_position(10, 9)
local SHADOW_END = grid.get_tile_position(12, 9)
local CREST_LOW = grid.get_tile_position(12, 10)
local CREST_HIGH = grid.get_tile_position(15, 5)
local HIT_BOMB_WALL = grid.get_tile_position(15, 7)
local TOP_REST = grid.get_tile_position(16, 1)
local CREST_WAYPOINTS: {Point} = {
    CREST_LOW,
    CREST_HIGH,
}

local CHASER_BOMB_BUDGET = 14
-- Wide enough to reach the victim pinned against the wall.
local CHASER_FIRE_RANGE = 4
local GLIDE_DEADBAND = 3
local ARRIVAL_MARGIN = 12
local DROP_SPACING = 10
local VICTIM_COMMIT_RANGE = 96
local CORNER_MARGIN = 16

local CYCLE_LENGTH = 5.5

local CHASER_SPRITE: CharacterName = "kotetsu"
local VICTIM_SPRITE: CharacterName = "white"
local BYSTANDER_SPRITE: CharacterName = "black"

local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(2, 1),
    soft_block_at(3, 1),
    soft_block_at(1, 4),
    soft_block_at(2, 3),
    soft_block_at(3, 2),
    soft_block_at(4, 1),
    soft_block_at(1, 9),
    soft_block_at(1, 8),
    soft_block_at(2, 9),
    soft_block_at(3, 9),
    soft_block_at(1, 6),
}

local ITEMS = {
    item_at(2, 5, "fire"),
    item_at(6, 2, "speed"),
    item_at(0, 0, "bomb"),
    item_at(1, 0, "bomb"),
    item_at(4, 10, "bomb"),
    item_at(5, 8, "bomb"),
    item_at(11, 0, "bomb"),
}

local type ChaserPhase = enum
    "herding"
    "shadowing"
    "sealing"
    "escaping"
    "resting"
end

local type VictimPhase = enum
    "fleeing"
    "climbing"
    "panic"
end

local record IceRinkPreview is Choreography
    stage: Stage
    chaser: Player
    victim: Player
    bystander: Player
    chaser_phase: ChaserPhase
    victim_phase: VictimPhase
    crest_leg: integer
    last_drop: Point
end

local ice_rink = {}

-- Releasing an axis inside the deadband lets momentum coast on, not judder.
local function glide_toward(from: Point, to: Point): {Direction}
    local offset = from:vector_to(to)
    local held: {Direction} = {}
    if offset.x > GLIDE_DEADBAND then
        table.insert(held, "right")
    elseif offset.x < -GLIDE_DEADBAND then
        table.insert(held, "left")
    end
    if offset.y > GLIDE_DEADBAND then
        table.insert(held, "down")
    elseif offset.y < -GLIDE_DEADBAND then
        table.insert(held, "up")
    end
    return held
end

function ice_rink.new_scenery(): Scenery
    return scenery.new("ice_rink", SOFT_BLOCKS, ITEMS)
end

function ice_rink.new_choreography(): Choreography
    local self: IceRinkPreview = setmetatable({}, {__index = IceRinkPreview})
    self.cycle_length = CYCLE_LENGTH
    return self
end

function IceRinkPreview:open(stage: Stage): {Player}
    self.stage = stage
    -- Not a kicker: a kick would scatter the seal it just laid.
    self.chaser = drones.bomber(
        CHASER_SPRITE, CHASER_START, CHASER_BOMB_BUDGET, CHASER_FIRE_RANGE
    )
    self.victim = drones.victim(VICTIM_SPRITE, VICTIM_START)
    self.bystander = drones.bystander(BYSTANDER_SPRITE, BYSTANDER_START)

    -- Pre-seeded so the loop opens mid-chase.
    local victim_glide = self.victim:get_speed()
    stage:slide(self.victim, vectors.new(victim_glide, victim_glide))
    stage:slide(self.chaser, vectors.new(0, self.chaser:get_speed()))

    self.chaser_phase = "herding"
    self.victim_phase = "fleeing"
    self.crest_leg = 1
    self.last_drop = CHASER_START
    return {self.chaser, self.victim, self.bystander}
end

function IceRinkPreview:_glide(mover: Player, target: Point)
    self.stage:set_player_inputs(mover, glide_toward(mover.position, target))
end

function IceRinkPreview:_chaser_reached(target: Point): boolean
    return self.chaser.position:distance_to(target) <= ARRIVAL_MARGIN
end

function IceRinkPreview:_choreograph_chaser()
    local chaser = self.chaser

    if self.chaser_phase == "herding" then
        self:_glide(chaser, HERD_JOIN)
        if self:_chaser_reached(HERD_JOIN) then
            self.chaser_phase = "shadowing"
        end
        return
    end

    if self.chaser_phase == "shadowing" then
        self:_glide(chaser, SHADOW_END)
        -- Earlier, the wall drops across the victim's path, not behind it.
        local to_corner = self.victim.position:distance_to(CORNER_REST)
        if self:_chaser_reached(SHADOW_END) and to_corner <= VICTIM_COMMIT_RANGE then
            self.chaser_phase = "sealing"
        end
        return
    end

    if self.chaser_phase == "sealing" then
        local target = CREST_WAYPOINTS[self.crest_leg]
        self:_glide(chaser, target)
        -- Sliding, it cannot lay a tidy line, so it drips by distance.
        if self.last_drop:distance_to(chaser.position) >= DROP_SPACING then
            self.stage:place_bomb(chaser)
            self.last_drop = chaser.position
        end
        if self:_chaser_reached(target) then
            self.crest_leg = self.crest_leg + 1
        end
        if self.crest_leg > #CREST_WAYPOINTS then
            self.chaser_phase = "escaping"
        end
        return
    end

    if self.chaser_phase == "escaping" then
        self:_glide(chaser, TOP_REST)
        if self:_chaser_reached(TOP_REST) then
            self.chaser_phase = "resting"
        end
        return
    end

    if self.chaser_phase == "resting" then
        self.stage:set_player_inputs(chaser, {})
        self.stage:face(chaser, "down")
    end
end

function IceRinkPreview:_choreograph_victim()
    if self.victim_phase == "fleeing" then
        self.stage:set_player_inputs(self.victim, {"down", "right"})
        if self.victim.position:distance_to(CORNER_REST) <= CORNER_MARGIN then
            self.victim_phase = "climbing"
        end
        return
    elseif self.victim_phase == "climbing" then
        self.stage:set_player_inputs(self.victim, {"up"})
        if self.victim.position:distance_to(HIT_BOMB_WALL) <= grid.TILE_SIZE * 1.5 then
            self.victim_phase = "panic"
        end
    elseif self.victim_phase == "panic" then
        self.stage:set_player_inputs(self.victim, {"down"})
    end
end

function IceRinkPreview:_choreograph_bystander()
    self:_glide(self.bystander, BYSTANDER_REST)
end

function IceRinkPreview:step(_dt: number)
    self:_choreograph_chaser()
    self:_choreograph_victim()
    self:_choreograph_bystander()
end

return ice_rink
