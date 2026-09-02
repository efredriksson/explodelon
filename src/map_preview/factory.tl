-- Factory preview: the kicker volleys bombs into the centre conveyor ring and
-- backs off; the chain reaction kills the victim pacing at the ring's core.

local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local drones = require("map_preview.drones")
local scripted_battle = require("map_preview.scripted_battle")
local players = require("players")

local type MapPreview = require("map_preview.interfaces")
local type Pacer = drones.Pacer
local type Player = players.Player
local type ScriptedBattle = scripted_battle.ScriptedBattle
local type SoftBlockConfig = map_entities.SoftBlockConfig

local soft_block_at = scripted_battle.soft_block_at
local item_at = scripted_battle.item_at

-- Row 2 is clear, so kicked bombs slide left into the conveyor ring.
local KICKER_START = grid.get_tile_position(14, 2)
local VICTIM_START = grid.get_tile_position(8, 5)

local KICKER_BOMBS = 4
-- Wider than default so ring-edge detonations reach the victim at the centre.
local KICKER_FIRE_RANGE = 4
local STEP_OFF_DISTANCE = 20
local RETURN_MARGIN = 1.75
local REST_DURATION = 0.15
-- After the last kick the kicker backs off so the chain reaction spares it.
local RETREAT_DISTANCE = 32

local PACE_RANGE = 16

local CYCLE_LENGTH = 4.4

-- Corner clutter plus a few by the ring for the chain reaction; none on a bomb path.
local SCENERY_SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(0, 9),
    soft_block_at(0, 10),
    soft_block_at(1, 10),
    soft_block_at(2, 10),
    soft_block_at(3, 2),
    soft_block_at(3, 4),
    soft_block_at(3, 8),
    soft_block_at(3, 10),
    soft_block_at(4, 9),
    soft_block_at(5, 10),
    soft_block_at(11, 10),
    soft_block_at(12, 9),
    soft_block_at(13, 8),
    soft_block_at(13, 10),
    soft_block_at(14, 10),
    soft_block_at(15, 10),
    soft_block_at(16, 9),
    soft_block_at(16, 10),
}

local SCENERY_ITEMS = {
    item_at(2, 9, "fire"),
    item_at(14, 9, "speed"),
    item_at(14, 3, "kick"),
}

local CONFIG = scripted_battle.WorldConfig.new(
    "factory", SCENERY_SOFT_BLOCKS, SCENERY_ITEMS
)

local type KickerPhase = enum
    "placing"
    "stepping_off"
    "returning"
    "retreating"
    "resting"
end

local record FactoryPreview is MapPreview
    battle: ScriptedBattle
    kicker: Player
    victim: Player
    victim_pacer: Pacer
    kicker_phase: KickerPhase
    kicker_rest_for: number
    bombs_placed: integer
    elapsed: number
end

local factory = {}

function FactoryPreview:_spawn_drones()
    self.kicker = drones.kicker(KICKER_START, KICKER_BOMBS, KICKER_FIRE_RANGE)
    self.victim = drones.victim(VICTIM_START)
end

function FactoryPreview:_start_cycle()
    self.kicker_phase = "placing"
    -- Pillars flank the ring centre, so the victim can only pace vertically.
    self.victim_pacer = drones.Pacer.new(self.victim, PACE_RANGE, "down")
    self.kicker_rest_for = 0
    self.bombs_placed = 0
    self.elapsed = 0
end

function factory.new(): MapPreview
    local self: FactoryPreview = setmetatable({}, {__index = FactoryPreview})
    self:_spawn_drones()
    self.battle = scripted_battle.new(CONFIG, {self.kicker, self.victim})
    self:_start_cycle()
    return self
end

function FactoryPreview:_restart()
    self:_spawn_drones()
    self.battle:reset({self.kicker, self.victim})
    self:_start_cycle()
end

function FactoryPreview:_choreograph_kicker(dt: number)
    local kicker = self.kicker

    if self.kicker_phase == "placing" then
        self.battle:place_bomb(kicker)
        self.bombs_placed = self.bombs_placed + 1
        self.battle:set_player_inputs(kicker, {})
        self.kicker_phase = "stepping_off"
        return
    end

    if self.kicker_phase == "stepping_off" then
        self.battle:set_player_inputs(kicker, {"right"})
        if kicker.position:distance_to(KICKER_START) >= STEP_OFF_DISTANCE then
            self.kicker_phase = "returning"
        end
        return
    end

    if self.kicker_phase == "returning" then
        self.battle:set_player_inputs(kicker, {"left"})
        if kicker.position:distance_to(KICKER_START) <= RETURN_MARGIN then
            if self.bombs_placed >= KICKER_BOMBS then
                self.kicker_phase = "retreating"
            else
                self.kicker_phase = "resting"
                self.kicker_rest_for = REST_DURATION
            end
        end
        return
    end

    if self.kicker_phase == "retreating" then
        self.battle:set_player_inputs(kicker, {"right"})
        if kicker.position:distance_to(KICKER_START) >= RETREAT_DISTANCE then
            self.kicker_phase = "resting"
        end
        return
    end

    if self.kicker_phase == "resting" then
        self.battle:set_player_inputs(kicker, {})
        self.kicker_rest_for = self.kicker_rest_for - dt
        if self.kicker_rest_for <= 0 and self.bombs_placed < KICKER_BOMBS then
            self.kicker_phase = "placing"
        end
    end
end

function FactoryPreview:_choreograph_victim()
    self.battle:set_player_inputs(self.victim, {self.victim_pacer:direction()})
end

function FactoryPreview:update(dt: number)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= CYCLE_LENGTH then
        self:_restart()
        return
    end

    self:_choreograph_kicker(dt)
    self:_choreograph_victim()
    self.battle:update(dt)
end

function FactoryPreview:draw()
    self.battle:draw()
end

function FactoryPreview:leave()
    self.battle:leave()
end

return factory
