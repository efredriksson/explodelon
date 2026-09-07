-- The bomber vaults clear of its own bomb; a wrapped launch pins the victim.

local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local players = require("players")
local choreography = require("preview.choreography")
local drones = require("preview.drones")
local scenery = require("preview.scenery")

local type Choreography = choreography.Choreography
local type Player = players.Player
local type Scenery = scenery.Scenery
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type Stage = choreography.Stage

local soft_block_at = scenery.soft_block_at
local item_at = scenery.item_at

local BOMBER_START = grid.get_tile_position(12, 6)
local BOMBER_TRAP = grid.get_tile_position(12, 0)
local VICTIM_START = grid.get_tile_position(12, 8)
local VICTIM_REST = grid.get_tile_position(12, 1)
local BYSTANDER_WEST = grid.get_tile_position(0, 6)
local BYSTANDER_EAST = grid.get_tile_position(8, 6)

local BOMBER_BOMBS = 3
local BOMBER_FIRE = 2
local ARRIVAL_MARGIN = 12
local RETREAT_DISTANCE = 44

local CYCLE_LENGTH = 5.5

local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(0, 0),
    soft_block_at(1, 0),
    soft_block_at(2, 0),
    soft_block_at(0, 2),
    soft_block_at(0, 3),
    soft_block_at(0, 4),
    soft_block_at(0, 8),
    soft_block_at(0, 9),
    soft_block_at(0, 10),
    soft_block_at(1, 10),
    soft_block_at(2, 10),
    soft_block_at(3, 10),
    soft_block_at(16, 0),
    soft_block_at(16, 1),
    soft_block_at(16, 9),
    soft_block_at(16, 10),
    soft_block_at(15, 10),
}

local ITEMS = {
    item_at(2, 2, "fire"),
    item_at(2, 9, "speed"),
}

local type BomberPhase = enum
    "arming"
    "vaulting"
    "trapping"
    "retreating"
    "resting"
end

local type VictimPhase = enum
    "approaching"
    "airborne"
    "wedging"
end

local type BystanderPhase = enum
    "going_east"
    "going_west"
end

local record BouncingPreview is Choreography
    stage: Stage
    bomber: Player
    victim: Player
    bystander: Player
    bomber_phase: BomberPhase
    victim_phase: VictimPhase
    bystander_phase: BystanderPhase
    escape_bomb_dropped: boolean
end

local bouncing = {}

function bouncing.new_scenery(): Scenery
    return scenery.new("bouncing", SOFT_BLOCKS, ITEMS)
end

function bouncing.new_choreography(): Choreography
    local self: BouncingPreview = setmetatable({}, {__index = BouncingPreview})
    self.cycle_length = CYCLE_LENGTH
    return self
end

function BouncingPreview:open(stage: Stage): {Player}
    self.stage = stage
    self.bomber = drones.bomber(BOMBER_START, BOMBER_BOMBS, BOMBER_FIRE)
    self.victim = drones.victim(VICTIM_START)
    self.bystander = drones.bystander(BYSTANDER_WEST)
    self.bomber_phase = "arming"
    self.victim_phase = "approaching"
    self.bystander_phase = "going_east"
    self.escape_bomb_dropped = false
    return {self.bomber, self.victim, self.bystander}
end

function BouncingPreview:_choreograph_bomber()
    local bomber = self.bomber

    if self.bomber_phase == "arming" then
        if not self.escape_bomb_dropped then
            self.stage:place_bomb(bomber)
            self.escape_bomb_dropped = true
        end
        -- "up" walks onto pad (12,4), which vaults it clear before the fuse.
        self.stage:set_player_inputs(bomber, {"up"})
        if bomber:is_bouncing() then
            self.bomber_phase = "vaulting"
        end
        return
    end

    if self.bomber_phase == "vaulting" then
        local landed = not bomber:is_bouncing()
        if landed and bomber.position:distance_to(BOMBER_TRAP) <= ARRIVAL_MARGIN then
            self.bomber_phase = "trapping"
        end
        return
    end

    if self.bomber_phase == "trapping" then
        self.stage:place_bomb(bomber)
        self.stage:set_player_inputs(bomber, {"down"})
        self.bomber_phase = "retreating"
        return
    end

    if self.bomber_phase == "retreating" then
        self.stage:set_player_inputs(bomber, {"down"})
        if bomber.position:distance_to(BOMBER_TRAP) >= RETREAT_DISTANCE then
            self.bomber_phase = "resting"
        end
        return
    end

    if self.bomber_phase == "resting" then
        self.stage:set_player_inputs(bomber, {})
    end
end

function BouncingPreview:_choreograph_victim()
    if self.victim_phase == "approaching" then
        self.stage:set_player_inputs(self.victim, {"down"})
        if self.victim:is_bouncing() then
            self.victim_phase = "airborne"
        end
        return
    end

    if self.victim_phase == "airborne" then
        -- The launch wraps off the bottom edge; the trap bomb blocks its tile,
        -- so it lands one short and wedges there.
        local landed = not self.victim:is_bouncing()
        if
            landed and self.victim.position:distance_to(VICTIM_REST) <= grid.TILE_SIZE
        then
            self.victim_phase = "wedging"
        end
        return
    end

    if self.victim_phase == "wedging" then
        self.stage:set_player_inputs(self.victim, {"up"})
    end
end

function BouncingPreview:_choreograph_bystander()
    local bystander = self.bystander

    -- A bounce is not a scripted phase; hold inputs until it lands.
    if bystander:is_bouncing() then
        return
    end

    if self.bystander_phase == "going_east" then
        self.stage:set_player_inputs(bystander, {"right"})
        if bystander.position:distance_to(BYSTANDER_EAST) <= ARRIVAL_MARGIN then
            self.bystander_phase = "going_west"
        end
        return
    end

    if self.bystander_phase == "going_west" then
        self.stage:set_player_inputs(bystander, {"left"})
        if bystander.position:distance_to(BYSTANDER_WEST) <= ARRIVAL_MARGIN then
            self.bystander_phase = "going_east"
        end
    end
end

function BouncingPreview:step(_dt: number)
    self:_choreograph_bomber()
    self:_choreograph_victim()
    self:_choreograph_bystander()
end

return bouncing
