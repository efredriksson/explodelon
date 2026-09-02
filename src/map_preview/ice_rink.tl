-- Ice-rink preview: the victim glides into the SE corner and the chaser seals
-- it there with a ragged wall of dripped bombs.

local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local drones = require("map_preview.drones")
local scripted_battle = require("map_preview.scripted_battle")
local players = require("players")

local type Direction = vectors.Direction
local type MapPreview = require("map_preview.interfaces")
local type Player = players.Player
local type Point = points.Point
local type ScriptedBattle = scripted_battle.ScriptedBattle
local type SoftBlockConfig = map_entities.SoftBlockConfig

local soft_block_at = scripted_battle.soft_block_at
local item_at = scripted_battle.item_at

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
-- Wider than default so the wall's blast arms reach the victim pinned against it.
local CHASER_FIRE_RANGE = 4
local GLIDE_DEADBAND = 3
local ARRIVAL_MARGIN = 12
local DROP_SPACING = 10
local VICTIM_COMMIT_RANGE = 96
local CORNER_MARGIN = 16

local CYCLE_LENGTH = 5.5

local SCENERY_SOFT_BLOCKS: {SoftBlockConfig} = {
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

local SCENERY_ITEMS = {
    item_at(2, 5, "fire"),
    item_at(6, 2, "speed"),
    item_at(0, 0, "bomb"),
    item_at(1, 0, "bomb"),
    item_at(4, 10, "bomb"),
    item_at(5, 8, "bomb"),
    item_at(11, 0, "bomb"),
}

local CONFIG = scripted_battle.WorldConfig.new(
    "ice_rink", SCENERY_SOFT_BLOCKS, SCENERY_ITEMS
)

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

local record IceRinkPreview is MapPreview
    battle: ScriptedBattle
    chaser: Player
    victim: Player
    bystander: Player
    chaser_phase: ChaserPhase
    victim_phase: VictimPhase
    crest_leg: integer
    last_drop: Point
    elapsed: number
end

local ice_rink = {}

-- Release an axis inside the deadband of `to` so the drone's momentum coasts it
-- onto the target instead of juddering back and forth across it on the ice.
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

function IceRinkPreview:_spawn_drones()
    -- A plain bomber, not drones.kicker: on the ice it slides back over its own
    -- wall, and a kick would scatter the seal it just laid.
    self.chaser = drones.bomber(CHASER_START, CHASER_BOMB_BUDGET, CHASER_FIRE_RANGE)
    self.victim = drones.victim(VICTIM_START)
    self.bystander = drones.bystander(BYSTANDER_START)

    -- Pre-seed the glide (ice_velocity caps at get_speed()) so the loop opens
    -- mid-chase, not from a standstill.
    local victim_glide = self.victim:get_speed()
    self.victim.ice_velocity = vectors.new(victim_glide, victim_glide)
    self.chaser.ice_velocity = vectors.new(0, self.chaser:get_speed())
end

function IceRinkPreview:_start_cycle()
    self.chaser_phase = "herding"
    self.victim_phase = "fleeing"
    self.crest_leg = 1
    self.last_drop = CHASER_START
    self.elapsed = 0
end

function ice_rink.new(): MapPreview
    local self: IceRinkPreview = setmetatable({}, {__index = IceRinkPreview})
    self:_spawn_drones()
    self.battle = scripted_battle.new(
        CONFIG, {self.chaser, self.victim, self.bystander}
    )
    self:_start_cycle()
    return self
end

function IceRinkPreview:_restart()
    self:_spawn_drones()
    self.battle:reset({self.chaser, self.victim, self.bystander})
    self:_start_cycle()
end

function IceRinkPreview:_glide(mover: Player, target: Point)
    self.battle:set_player_inputs(mover, glide_toward(mover.position, target))
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
        -- Wait for the victim to commit to the corner, or the wall drops across
        -- its path instead of behind it.
        local to_corner = self.victim.position:distance_to(CORNER_REST)
        if self:_chaser_reached(SHADOW_END) and to_corner <= VICTIM_COMMIT_RANGE then
            self.chaser_phase = "sealing"
        end
        return
    end

    if self.chaser_phase == "sealing" then
        local target = CREST_WAYPOINTS[self.crest_leg]
        self:_glide(chaser, target)
        -- Sliding, the chaser can't lay a tidy line, so it drips a bomb every
        -- DROP_SPACING of travel and takes whatever ragged wall falls.
        if self.last_drop:distance_to(chaser.position) >= DROP_SPACING then
            self.battle:place_bomb(chaser)
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
        self.battle:set_player_inputs(chaser, {})
        self.chaser.direction = "down"
    end
end

function IceRinkPreview:_choreograph_victim()
    if self.victim_phase == "fleeing" then
        self.battle:set_player_inputs(self.victim, {"down", "right"})
        if self.victim.position:distance_to(CORNER_REST) <= CORNER_MARGIN then
            self.victim_phase = "climbing"
        end
        return
    elseif self.victim_phase == "climbing" then
        self.battle:set_player_inputs(self.victim, {"up"})
        if self.victim.position:distance_to(HIT_BOMB_WALL) <= grid.TILE_SIZE * 1.5 then
            self.victim_phase = "panic"
        end
    elseif self.victim_phase == "panic" then
        self.battle:set_player_inputs(self.victim, {"down"})
    end
end

function IceRinkPreview:_choreograph_bystander()
    self:_glide(self.bystander, BYSTANDER_REST)
end

function IceRinkPreview:update(dt: number)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= CYCLE_LENGTH then
        self:_restart()
        return
    end

    self:_choreograph_chaser()
    self:_choreograph_victim()
    self:_choreograph_bystander()
    self.battle:update(dt)
end

function IceRinkPreview:draw()
    self.battle:draw()
end

function IceRinkPreview:leave()
    self.battle:leave()
end

return ice_rink
