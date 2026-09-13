-- A goal bomb kills the victim pacing the next lane over.

local characters = require("characters")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local players = require("players")
local choreography = require("preview.choreography")
local drones = require("preview.drones")
local scenery = require("preview.scenery")

local type CharacterName = characters.CharacterName
local type Choreography = choreography.Choreography
local type KickCycle = drones.KickCycle
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
local ROW_4_CLEARANCE = 28

local PACE_RANGE = 200

local CYCLE_LENGTH = 3.3

local KICKER_SPRITE: CharacterName = "kotetsu"
local VICTIM_SPRITE: CharacterName = "white"

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

local record FootballPreview is Choreography
    stage: Stage
    kicker: Player
    victim: Player
    victim_pacer: Pacer
    kick_cycle: KickCycle
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
    self.kicker = drones.kicker(
        KICKER_SPRITE, KICKER_START, KICKER_BOMBS, KICKER_FIRE_RANGE
    )
    self.victim = drones.victim(VICTIM_SPRITE, VICTIM_START)
    self.kick_cycle = drones.KickCycle.new(
        self.kicker, KICKER_BOMBS, "up", ROW_4_CLEARANCE
    )
    self.victim_pacer = drones.Pacer.new(self.victim, PACE_RANGE, "right")
    return {self.kicker, self.victim}
end

function FootballPreview:step(dt: number)
    self.kick_cycle:steer(self.stage, dt)
    self.victim_pacer:steer(self.stage)
end

return football
