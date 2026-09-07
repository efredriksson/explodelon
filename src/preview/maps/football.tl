-- A goal bomb kills the victim pacing the next lane over.

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

-- Row 4 is clear to the goal, so the kick slides in.
local KICKER_START = grid.get_tile_position(8, 4)
-- Row 6 is the other goal lane; goal.pair blasts its far end.
local VICTIM_START = grid.get_tile_position(2, 6)

local KICKER_BOMBS = 1
local KICKER_FIRE_RANGE = 1
local STEP_OFF_DISTANCE = 20
local RETURN_MARGIN = 1.75
local ROW_4_CLEARANCE = 28

local PACE_RANGE = 200

local CYCLE_LENGTH = 3.3

-- (10,4)/(12,6) pop for the goal blasts; the rest of rows 4 and 6 stay clear.
local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(0, 8),
    soft_block_at(0, 9),
    soft_block_at(0, 10),
    soft_block_at(1, 10),
    soft_block_at(2, 10),
    soft_block_at(3, 10),
    soft_block_at(5, 10),
    soft_block_at(6, 8),
    soft_block_at(10, 8),
    soft_block_at(11, 4),
    soft_block_at(11, 10),
    soft_block_at(12, 6),
    soft_block_at(13, 10),
    soft_block_at(14, 10),
    soft_block_at(15, 10),
    soft_block_at(16, 8),
    soft_block_at(16, 9),
    soft_block_at(16, 10),
}

local ITEMS = {
    item_at(2, 9, "fire"),
    item_at(14, 9, "speed"),
    item_at(8, 5, "kick"),
}

local type KickerPhase = enum
    "placing"
    "stepping_off"
    "returning"
    "clearing"
    "resting"
end

local record FootballPreview is Choreography
    stage: Stage
    kicker: Player
    victim: Player
    victim_pacer: Pacer
    kicker_phase: KickerPhase
end

local football = {}

function football.new_scenery(): Scenery
    return scenery.new("football", SOFT_BLOCKS, ITEMS)
end

function football.new_choreography(): Choreography
    local self: FootballPreview = setmetatable({}, {__index = FootballPreview})
    self.cycle_length = CYCLE_LENGTH
    return self
end

function FootballPreview:open(stage: Stage): {Player}
    self.stage = stage
    self.kicker = drones.kicker(KICKER_START, KICKER_BOMBS, KICKER_FIRE_RANGE)
    self.victim = drones.victim(VICTIM_START)
    self.kicker_phase = "placing"
    self.victim_pacer = drones.Pacer.new(self.victim, PACE_RANGE, "right")
    return {self.kicker, self.victim}
end

function FootballPreview:_choreograph_kicker()
    local kicker = self.kicker

    if self.kicker_phase == "placing" then
        self.stage:place_bomb(kicker)
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
            self.kicker_phase = "clearing"
        end
        return
    end

    if self.kicker_phase == "clearing" then
        self.stage:set_player_inputs(kicker, {"up"})
        if kicker.position:distance_to(KICKER_START) >= ROW_4_CLEARANCE then
            self.kicker_phase = "resting"
        end
        return
    end

    if self.kicker_phase == "resting" then
        self.stage:set_player_inputs(kicker, {})
    end
end

function FootballPreview:step(_dt: number)
    self:_choreograph_kicker()
    self.victim_pacer:steer(self.stage)
end

return football
