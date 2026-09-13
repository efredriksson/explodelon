-- Bombs volleyed into the conveyor ring chain-react on the victim at its core.

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

-- Row 2 is clear, so kicked bombs slide left into the ring.
local KICKER_START = grid.get_tile_position(14, 2)
local VICTIM_START = grid.get_tile_position(8, 5)

local KICKER_BOMBS = 4
-- Wide enough that ring-edge blasts reach the centre.
local KICKER_FIRE_RANGE = 4
local REST_DURATION = 0.15
local CHAIN_REACTION_CLEARANCE = 32

local PACE_RANGE = 16

local CYCLE_LENGTH = 4.4

local KICKER_SPRITE: CharacterName = "kotetsu"
local VICTIM_SPRITE: CharacterName = "white"

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

local record FactoryPreview is Choreography
    stage: Stage
    kicker: Player
    victim: Player
    victim_pacer: Pacer
    kick_cycle: KickCycle
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
    self.kicker = drones.kicker(
        KICKER_SPRITE, KICKER_START, KICKER_BOMBS, KICKER_FIRE_RANGE
    )
    self.victim = drones.victim(VICTIM_SPRITE, VICTIM_START)
    self.kick_cycle = drones.KickCycle.new(
        self.kicker, KICKER_BOMBS, "right", CHAIN_REACTION_CLEARANCE, REST_DURATION
    )
    -- Pillars flank the ring centre, so the victim paces vertically.
    self.victim_pacer = drones.Pacer.new(self.victim, PACE_RANGE, "down")
    return {self.kicker, self.victim}
end

function FactoryPreview:step(dt: number)
    self.kick_cycle:steer(self.stage, dt)
    self.victim_pacer:steer(self.stage)
end

return factory
