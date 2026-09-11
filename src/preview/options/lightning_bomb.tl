local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local players = require("players")
local choreography = require("preview.choreography")
local drones = require("preview.drones")
local window = require("preview.options.window")
local scenery = require("preview.scenery")
local settings = require("settings")

local type Choreography = choreography.Choreography
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point
local type Scenery = scenery.Scenery
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type Stage = choreography.Stage

local soft_block_at = scenery.soft_block_at

local WALK_ROW = window.FIRST_ROW + 2
local ENTRY_COLUMN = window.FIRST_COLUMN - 1
local BOMB_COLUMN = window.FIRST_COLUMN + 1
local VICTIM_COLUMN = window.LAST_COLUMN - 1
local VICTIM_ROW = window.LAST_ROW

-- One past LightningBomb.new's range constant.
local SAFE_MARGIN = 7
local EXIT_COLUMN = BOMB_COLUMN - SAFE_MARGIN

local WALKER_SPEED = 45
local PLAYBACK_RATE = 2
-- 5s fuse; rest covers entry/flight/blast.
local CYCLE_LENGTH = 8

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local BOMB_TILE = corridor_tile_at(BOMB_COLUMN)
local VICTIM_TILE = grid.get_tile_position(VICTIM_COLUMN, VICTIM_ROW)
local EXIT_TILE = corridor_tile_at(EXIT_COLUMN)

-- Within blast reach, off the walker's path — stands through unbroken.
local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(VICTIM_COLUMN - 1, window.FIRST_ROW + 1),
}

local type WalkerPhase = enum
    "entering"
    "fleeing"
    "watching"
end

local record LightningBombLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
end

local lightning_bomb = {}

function lightning_bomb.new_scenery(): Scenery
    return scenery.new(settings.map, SOFT_BLOCKS, {})
end

function lightning_bomb.new_choreography(): Choreography
    local self: LightningBombLesson = setmetatable({}, {__index = LightningBombLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function LightningBombLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(ENTRY_TILE, nil, nil, 1)
    self.walker.speed = WALKER_SPEED
    self.phase = "entering"
    local victim = drones.victim(VICTIM_TILE)
    return {self.walker, victim}
end

function LightningBombLesson:_has_walked_to(tile: Point): boolean
    return self.walker.position.x >= tile.x
end

function LightningBombLesson:_has_retreated_to(tile: Point): boolean
    return self.walker.position.x <= tile.x
end

function LightningBombLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function LightningBombLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function LightningBombLesson:step(_dt: number)
    if self.phase == "entering" then
        self:_walk("right")
        if self:_has_walked_to(BOMB_TILE) then
            self.stage:place_lightning_bomb(self.walker)
            self.phase = "fleeing"
        end
        return
    end

    if self.phase == "fleeing" then
        self:_walk("left")
        if self:_has_retreated_to(EXIT_TILE) then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return lightning_bomb
