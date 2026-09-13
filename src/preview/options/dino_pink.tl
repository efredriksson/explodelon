-- The pink dino lesson: jumps two walls back-to-back to reach a treasure trove.

local characters = require("characters")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local grid = require("level_layout.grid")
local players = require("players")
local choreography = require("preview.choreography")
local drones = require("preview.drones")
local window = require("preview.options.window")
local scenery = require("preview.scenery")
local settings = require("settings")

local type CharacterName = characters.CharacterName
local type Choreography = choreography.Choreography
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point
local type Scenery = scenery.Scenery
local type Stage = choreography.Stage

local WALK_ROW = window.FIRST_ROW + 2

local ENTRY_COLUMN = window.FIRST_COLUMN - 1
local TAKEOFF_1_COLUMN = window.FIRST_COLUMN
local WALL_1_COLUMN = TAKEOFF_1_COLUMN + 1
local TAKEOFF_2_COLUMN = TAKEOFF_1_COLUMN + 2
local WALL_2_COLUMN = TAKEOFF_1_COLUMN + 3
local LANDING_2_COLUMN = TAKEOFF_1_COLUMN + 4
local TREASURE_COLUMN = TAKEOFF_1_COLUMN + 5

local WALKER_SPEED = 35
-- WALKER_SPEED doesn't evenly divide TILE_SIZE, use a margin for stop:
local STOP_MARGIN = 1
local PLAYBACK_RATE = 2
local CHARGE_DURATION = 0.5
local CYCLE_LENGTH = 4.0
local WALKER_SPRITE: CharacterName = "bonks"

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local TAKEOFF_1_TILE = corridor_tile_at(TAKEOFF_1_COLUMN)
local LANDING_1_TILE = corridor_tile_at(TAKEOFF_2_COLUMN)
local LANDING_2_TILE = corridor_tile_at(LANDING_2_COLUMN)
local TREASURE_TILE = corridor_tile_at(TREASURE_COLUMN)

local type WalkerPhase = enum
    "mounting"
    "approaching"
    "charging_1"
    "jumping_1"
    "charging_2"
    "jumping_2"
    "looting"
    "watching"
end

local record DinoPinkLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
    charge_elapsed: number
end

local dino_pink = {}

-- Walls sit on the checkerboard's even columns, so they never land on one of
-- block_layouts.grid's fixed hard-block pillars (odd column AND odd row).
function dino_pink.new_scenery(): Scenery
    return scenery.new(
        settings.map,
        {
            scenery.soft_block_at(WALL_1_COLUMN, window.FIRST_ROW + 1),
            scenery.soft_block_at(WALL_1_COLUMN, WALK_ROW),
            scenery.soft_block_at(WALL_1_COLUMN, window.FIRST_ROW + 3),
            scenery.soft_block_at(WALL_2_COLUMN, window.FIRST_ROW + 1),
            scenery.soft_block_at(WALL_2_COLUMN, WALK_ROW),
            scenery.soft_block_at(WALL_2_COLUMN, window.FIRST_ROW + 3),
        },
        {
            scenery.item_at(TREASURE_COLUMN, window.FIRST_ROW + 1, "fire"),
            scenery.item_at(TREASURE_COLUMN, WALK_ROW, "kick"),
            scenery.item_at(TREASURE_COLUMN, window.FIRST_ROW + 3, "speed"),
        }
    )
end

function dino_pink.new_choreography(): Choreography
    local self: DinoPinkLesson = setmetatable({}, {__index = DinoPinkLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function DinoPinkLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE)
    self.walker.speed = WALKER_SPEED
    self.phase = "mounting"
    return {self.walker}
end

function DinoPinkLesson:_has_walked_to(tile: Point, margin?: number): boolean
    return self.walker.position.x >= tile.x - (margin or 0)
end

function DinoPinkLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function DinoPinkLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function DinoPinkLesson:step(dt: number)
    if self.phase == "mounting" then
        self.stage:mount_dino(self.walker, "pink")
        self.phase = "approaching"
        return
    end

    if self.phase == "approaching" then
        self:_walk("right")
        if self:_has_walked_to(TAKEOFF_1_TILE, STOP_MARGIN) then
            self:_stand()
            self.charge_elapsed = 0
            self.phase = "charging_1"
        end
        return
    end

    if self.phase == "charging_1" then
        self:_stand()
        self.charge_elapsed = self.charge_elapsed + dt
        if self.charge_elapsed >= CHARGE_DURATION then
            self.stage:jump_with_dino(self.walker, LANDING_1_TILE)
            self.phase = "jumping_1"
        end
        return
    end

    if self.phase == "jumping_1" then
        self:_stand()
        if not self.walker:is_jumping() then
            self.charge_elapsed = 0
            self.phase = "charging_2"
        end
        return
    end

    if self.phase == "charging_2" then
        self:_stand()
        self.charge_elapsed = self.charge_elapsed + dt
        if self.charge_elapsed >= CHARGE_DURATION then
            self.stage:jump_with_dino(self.walker, LANDING_2_TILE)
            self.phase = "jumping_2"
        end
        return
    end

    if self.phase == "jumping_2" then
        self:_stand()
        if not self.walker:is_jumping() then
            self.phase = "looting"
        end
        return
    end

    if self.phase == "looting" then
        self:_walk("right")
        if self:_has_walked_to(TREASURE_TILE) then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return dino_pink
