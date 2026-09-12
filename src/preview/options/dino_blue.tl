-- The blue dino lession: throws bomb which bounces on other bomb and victim.

local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
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
local type Stage = choreography.Stage

local WALK_ROW = window.FIRST_ROW + 2
local ENTRY_COLUMN = window.FIRST_COLUMN - 1
local STOP_COLUMN = window.FIRST_COLUMN + 1
local BOMB_A_COLUMN = window.FIRST_COLUMN + 2
local BOMB_B_COLUMN = window.FIRST_COLUMN + 3
local VICTIM_COLUMN = window.FIRST_COLUMN + 4

local BOMB_FIRE = 2

local WALKER_SPEED = 35
-- WALKER_SPEED doesn't evenly divide TILE_SIZE, use a margin for stop:
local STOP_MARGIN = 1
local PLAYBACK_RATE = 2
local AFTER_THROW_WAIT_DURATION = 1
local CYCLE_LENGTH = 3.0

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local STOP_TILE = corridor_tile_at(STOP_COLUMN)
local BOMB_B_TILE = corridor_tile_at(BOMB_B_COLUMN)
local VICTIM_TILE = corridor_tile_at(VICTIM_COLUMN)
local SCENERY_BOMBS = {
    scenery.bomb_at(BOMB_A_COLUMN, WALK_ROW, BOMB_FIRE),
    scenery.bomb_at(BOMB_B_COLUMN, WALK_ROW, BOMB_FIRE),
}

local type WalkerPhase = enum
    "mounting"
    "approaching"
    "waiting"
    "fleeing"
    "watching"
end

local record DinoBlueLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
    wait_elapsed: number
end

local dino_blue = {}

function dino_blue.new_scenery(): Scenery
    return scenery.new(settings.map, {}, {}, nil, SCENERY_BOMBS)
end

function dino_blue.new_choreography(): Choreography
    local self: DinoBlueLesson = setmetatable({}, {__index = DinoBlueLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function DinoBlueLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(ENTRY_TILE)
    self.walker.speed = WALKER_SPEED
    self.phase = "mounting"
    local victim = drones.victim(VICTIM_TILE)
    return {self.walker, victim}
end

function DinoBlueLesson:_has_walked_to(tile: Point, margin?: number): boolean
    return self.walker.position.x >= tile.x - (margin or 0)
end

function DinoBlueLesson:_has_retreated_to(tile: Point): boolean
    return self.walker.position.x <= tile.x
end

function DinoBlueLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function DinoBlueLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function DinoBlueLesson:step(dt: number)
    if self.phase == "mounting" then
        self.stage:mount_dino(self.walker, "blue")
        self.phase = "approaching"
        return
    end

    if self.phase == "approaching" then
        self:_walk("right")
        if self:_has_walked_to(STOP_TILE, STOP_MARGIN) then
            self.stage:throw_bomb_with_dino(self.walker, BOMB_B_TILE)
            self.phase = "waiting"
            self.wait_elapsed = 0
        end
        return
    end

    if self.phase == "waiting" then
        self:_stand()
        self.wait_elapsed = self.wait_elapsed + dt
        if self.wait_elapsed >= AFTER_THROW_WAIT_DURATION then
            self.phase = "fleeing"
        end
        return
    end

    if self.phase == "fleeing" then
        -- Bombs blast chain-explotions reach STOP_TILE,
        -- retreat past ENTRY_TILE to be safe.
        self:_walk("left")
        if self:_has_retreated_to(ENTRY_TILE) then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return dino_blue
