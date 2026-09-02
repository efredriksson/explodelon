-- Football preview: the kicker puts one bomb in the goal and clears north;
-- the paired goal blast down the next lane over kills the victim pacing there.

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

-- Row 4 runs clear to the left goal, so a westward kick slides straight in.
local KICKER_START = grid.get_tile_position(8, 4)
-- Row 6 is the other goal lane; the paired blast from its far end (goal.pair)
-- kills the pacing victim though no bomb ever travels here.
local VICTIM_START = grid.get_tile_position(2, 6)

local KICKER_BOMBS = 1
local KICKER_FIRE_RANGE = 1
local STEP_OFF_DISTANCE = 20
local RETURN_MARGIN = 1.75
-- The kicker clears north off row 4 before the primary blast sweeps it.
local CLEAR_DISTANCE = 28

local PACE_RANGE = 200

local CYCLE_LENGTH = 3.3

-- Corner clutter, plus (10,4)/(12,6) for the goal blasts to pop. Keep the rest
-- of rows 4 and 6 clear or a blast stops short.
local SCENERY_SOFT_BLOCKS: {SoftBlockConfig} = {
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

local SCENERY_ITEMS = {
    item_at(2, 9, "fire"),
    item_at(14, 9, "speed"),
    item_at(8, 5, "kick"),
}

local CONFIG = scripted_battle.WorldConfig.new(
    "football", SCENERY_SOFT_BLOCKS, SCENERY_ITEMS
)

local type KickerPhase = enum
    "placing"
    "stepping_off"
    "returning"
    "clearing"
    "resting"
end

local record FootballPreview is MapPreview
    battle: ScriptedBattle
    kicker: Player
    victim: Player
    victim_pacer: Pacer
    kicker_phase: KickerPhase
    elapsed: number
end

local football = {}

function FootballPreview:_spawn_drones()
    self.kicker = drones.kicker(KICKER_START, KICKER_BOMBS, KICKER_FIRE_RANGE)
    self.victim = drones.victim(VICTIM_START)
end

function FootballPreview:_start_cycle()
    self.kicker_phase = "placing"
    self.victim_pacer = drones.Pacer.new(self.victim, PACE_RANGE, "right")
    self.elapsed = 0
end

function football.new(): MapPreview
    local self: FootballPreview = setmetatable({}, {__index = FootballPreview})
    self:_spawn_drones()
    self.battle = scripted_battle.new(CONFIG, {self.kicker, self.victim})
    self:_start_cycle()
    return self
end

function FootballPreview:_restart()
    self:_spawn_drones()
    self.battle:reset({self.kicker, self.victim})
    self:_start_cycle()
end

function FootballPreview:_choreograph_kicker()
    local kicker = self.kicker

    if self.kicker_phase == "placing" then
        self.battle:place_bomb(kicker)
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
            self.kicker_phase = "clearing"
        end
        return
    end

    if self.kicker_phase == "clearing" then
        self.battle:set_player_inputs(kicker, {"up"})
        if kicker.position:distance_to(KICKER_START) >= CLEAR_DISTANCE then
            self.kicker_phase = "resting"
        end
        return
    end

    if self.kicker_phase == "resting" then
        self.battle:set_player_inputs(kicker, {})
    end
end

function FootballPreview:_choreograph_victim()
    self.battle:set_player_inputs(self.victim, {self.victim_pacer:direction()})
end

function FootballPreview:update(dt: number)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= CYCLE_LENGTH then
        self:_restart()
        return
    end

    self:_choreograph_kicker()
    self:_choreograph_victim()
    self.battle:update(dt)
end

function FootballPreview:draw()
    self.battle:draw()
end

function FootballPreview:leave()
    self.battle:leave()
end

return football
