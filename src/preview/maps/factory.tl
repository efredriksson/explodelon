-- Bombs volleyed into the conveyor ring chain-react on the victim at its core.

local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local players = require("players")
local choreography = require("preview.choreography")
local drones = require("preview.drones")
local scenery = require("preview.scenery")

local type Choreography = choreography.Choreography
local type Pacer = drones.Pacer
local type Player = players.Player
local type Scenery = scenery.Scenery
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type Stage = choreography.Stage

local soft_block_at = scenery.soft_block_at
local item_at = scenery.item_at

-- Row 2 is clear, so kicked bombs slide left into the ring.
local KICKER_START = grid.get_tile_position(14, 2)
local VICTIM_START = grid.get_tile_position(8, 5)

local KICKER_BOMBS = 4
-- Wide enough that ring-edge blasts reach the centre.
local KICKER_FIRE_RANGE = 4
local STEP_OFF_DISTANCE = 20
local RETURN_MARGIN = 1.75
local REST_DURATION = 0.15
local CHAIN_REACTION_CLEARANCE = 32

local PACE_RANGE = 16

local CYCLE_LENGTH = 4.4

-- None on a bomb path; those by the ring feed the chain reaction.
local SOFT_BLOCKS: {SoftBlockConfig} = {
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

local ITEMS = {
    item_at(2, 9, "fire"),
    item_at(14, 9, "speed"),
    item_at(14, 3, "kick"),
}

local type KickerPhase = enum
    "placing"
    "stepping_off"
    "returning"
    "retreating"
    "resting"
end

local record FactoryPreview is Choreography
    stage: Stage
    kicker: Player
    victim: Player
    victim_pacer: Pacer
    kicker_phase: KickerPhase
    kicker_rest_for: number
    bombs_placed: integer
end

local factory = {}

function factory.new_scenery(): Scenery
    return scenery.new("factory", SOFT_BLOCKS, ITEMS)
end

function factory.new_choreography(): Choreography
    local self: FactoryPreview = setmetatable({}, {__index = FactoryPreview})
    self.cycle_length = CYCLE_LENGTH
    return self
end

function FactoryPreview:open(stage: Stage): {Player}
    self.stage = stage
    self.kicker = drones.kicker(KICKER_START, KICKER_BOMBS, KICKER_FIRE_RANGE)
    self.victim = drones.victim(VICTIM_START)
    self.kicker_phase = "placing"
    -- Pillars flank the ring centre, so the victim paces vertically.
    self.victim_pacer = drones.Pacer.new(self.victim, PACE_RANGE, "down")
    self.kicker_rest_for = 0
    self.bombs_placed = 0
    return {self.kicker, self.victim}
end

function FactoryPreview:_choreograph_kicker(dt: number)
    local kicker = self.kicker

    if self.kicker_phase == "placing" then
        self.stage:place_bomb(kicker)
        self.bombs_placed = self.bombs_placed + 1
        self.stage:set_player_inputs(kicker, {})
        self.kicker_phase = "stepping_off"
        return
    end

    if self.kicker_phase == "stepping_off" then
        self.stage:set_player_inputs(kicker, {"right"})
        if kicker.position:distance_to(KICKER_START) >= STEP_OFF_DISTANCE then
            self.kicker_phase = "returning"
        end
        return
    end

    if self.kicker_phase == "returning" then
        self.stage:set_player_inputs(kicker, {"left"})
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
        self.stage:set_player_inputs(kicker, {"right"})
        if kicker.position:distance_to(KICKER_START) >= CHAIN_REACTION_CLEARANCE then
            self.kicker_phase = "resting"
        end
        return
    end

    if self.kicker_phase == "resting" then
        self.stage:set_player_inputs(kicker, {})
        self.kicker_rest_for = self.kicker_rest_for - dt
        if self.kicker_rest_for <= 0 and self.bombs_placed < KICKER_BOMBS then
            self.kicker_phase = "placing"
        end
    end
end

function FactoryPreview:step(dt: number)
    self:_choreograph_kicker(dt)
    self.victim_pacer:steer(self.stage)
end

return factory
