-- Bouncing preview: the bomber vaults off a trampoline clear of its own bomb;
-- the victim launches off the bottom edge, wraps to the top and a bomb pins it.

local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local drones = require("map_preview.drones")
local scripted_battle = require("map_preview.scripted_battle")
local players = require("players")

local type MapPreview = require("map_preview.interfaces")
local type Player = players.Player
local type ScriptedBattle = scripted_battle.ScriptedBattle
local type SoftBlockConfig = map_entities.SoftBlockConfig

local soft_block_at = scripted_battle.soft_block_at
local item_at = scripted_battle.item_at

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

local SCENERY_SOFT_BLOCKS: {SoftBlockConfig} = {
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

local SCENERY_ITEMS = {
    item_at(2, 2, "fire"),
    item_at(2, 9, "speed"),
}

local CONFIG = scripted_battle.WorldConfig.new(
    "bouncing", SCENERY_SOFT_BLOCKS, SCENERY_ITEMS
)

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

local record BouncingPreview is MapPreview
    battle: ScriptedBattle
    bomber: Player
    victim: Player
    bystander: Player
    bomber_phase: BomberPhase
    victim_phase: VictimPhase
    bystander_phase: BystanderPhase
    escape_bomb_dropped: boolean
    elapsed: number
end

local bouncing = {}

function BouncingPreview:_spawn_drones()
    self.bomber = drones.bomber(BOMBER_START, BOMBER_BOMBS, BOMBER_FIRE)
    self.victim = drones.victim(VICTIM_START)
    self.bystander = drones.bystander(BYSTANDER_WEST)
end

function BouncingPreview:_start_cycle()
    self.bomber_phase = "arming"
    self.victim_phase = "approaching"
    self.bystander_phase = "going_east"
    self.escape_bomb_dropped = false
    self.elapsed = 0
end

function bouncing.new(): MapPreview
    local self: BouncingPreview = setmetatable({}, {__index = BouncingPreview})
    self:_spawn_drones()
    self.battle = scripted_battle.new(
        CONFIG, {self.bomber, self.victim, self.bystander}
    )
    self:_start_cycle()
    return self
end

function BouncingPreview:_restart()
    self:_spawn_drones()
    self.battle:reset({self.bomber, self.victim, self.bystander})
    self:_start_cycle()
end

function BouncingPreview:_choreograph_bomber()
    local bomber = self.bomber

    if self.bomber_phase == "arming" then
        if not self.escape_bomb_dropped then
            self.battle:place_bomb(bomber)
            self.escape_bomb_dropped = true
        end
        -- Holding "up" walks the bomber straight onto pad (12,4); the trampoline
        -- turns that step into the vault that clears its own bomb before the fuse.
        self.battle:set_player_inputs(bomber, {"up"})
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
        self.battle:place_bomb(bomber)
        self.battle:set_player_inputs(bomber, {"down"})
        self.bomber_phase = "retreating"
        return
    end

    if self.bomber_phase == "retreating" then
        self.battle:set_player_inputs(bomber, {"down"})
        if bomber.position:distance_to(BOMBER_TRAP) >= RETREAT_DISTANCE then
            self.bomber_phase = "resting"
        end
        return
    end

    if self.bomber_phase == "resting" then
        self.battle:set_player_inputs(bomber, {})
    end
end

function BouncingPreview:_choreograph_victim()
    if self.victim_phase == "approaching" then
        self.battle:set_player_inputs(self.victim, {"down"})
        if self.victim:is_bouncing() then
            self.victim_phase = "airborne"
        end
        return
    end

    if self.victim_phase == "airborne" then
        -- The down launch overshoots the map edge, so the bounce wraps to the top
        -- and hops back down; the trap bomb blocks its tile, so it lands one short
        -- and wedges against the edge for the blast.
        local landed = not self.victim:is_bouncing()
        if
            landed and self.victim.position:distance_to(VICTIM_REST) <= grid.TILE_SIZE
        then
            self.victim_phase = "wedging"
        end
        return
    end

    if self.victim_phase == "wedging" then
        self.battle:set_player_inputs(self.victim, {"up"})
    end
end

function BouncingPreview:_choreograph_bystander()
    local bystander = self.bystander

    -- A bounce here is not a scripted phase; hold inputs until it lands and paces
    -- again, unlike the bomber and victim which resolve their arcs by phase.
    if bystander:is_bouncing() then
        return
    end

    if self.bystander_phase == "going_east" then
        self.battle:set_player_inputs(bystander, {"right"})
        if bystander.position:distance_to(BYSTANDER_EAST) <= ARRIVAL_MARGIN then
            self.bystander_phase = "going_west"
        end
        return
    end

    if self.bystander_phase == "going_west" then
        self.battle:set_player_inputs(bystander, {"left"})
        if bystander.position:distance_to(BYSTANDER_WEST) <= ARRIVAL_MARGIN then
            self.bystander_phase = "going_east"
        end
    end
end

function BouncingPreview:update(dt: number)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= CYCLE_LENGTH then
        self:_restart()
        return
    end

    self:_choreograph_bomber()
    self:_choreograph_victim()
    self:_choreograph_bystander()
    self.battle:update(dt)
end

function BouncingPreview:draw()
    self.battle:draw()
end

function BouncingPreview:leave()
    self.battle:leave()
end

return bouncing
