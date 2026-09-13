-- The green dino lesson: dashes down a lane of items and crashes into a wall.

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
local TAKEOFF_COLUMN = window.FIRST_COLUMN
local ITEM_1_COLUMN = TAKEOFF_COLUMN + 1
local ITEM_2_COLUMN = TAKEOFF_COLUMN + 2
local ITEM_3_COLUMN = TAKEOFF_COLUMN + 3
local ITEM_4_COLUMN = TAKEOFF_COLUMN + 4
local WALL_COLUMN = TAKEOFF_COLUMN + 5

local WALKER_SPEED = 45
-- WALKER_SPEED doesn't evenly divide TILE_SIZE, use a margin for stop:
local STOP_MARGIN = 1
local PLAYBACK_RATE = 2
local CYCLE_LENGTH = 2.8
local WALKER_SPRITE: CharacterName = "white"

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local TAKEOFF_TILE = corridor_tile_at(TAKEOFF_COLUMN)

local type WalkerPhase = enum
    "mounting"
    "approaching"
    "dashing"
    "crashed"
    "watching"
end

local record DinoGreenLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
end

local dino_green = {}

function dino_green.new_scenery(): Scenery
    return scenery.new(
        settings.map,
        {
            scenery.soft_block_at(WALL_COLUMN, window.FIRST_ROW + 1),
            scenery.soft_block_at(WALL_COLUMN, window.FIRST_ROW + 3),
        },
        {
            scenery.item_at(ITEM_1_COLUMN, WALK_ROW, "fire"),
            scenery.item_at(ITEM_2_COLUMN, WALK_ROW, "kick"),
            scenery.item_at(ITEM_3_COLUMN, WALK_ROW, "speed"),
            scenery.item_at(ITEM_4_COLUMN, WALK_ROW, "lightning_bomb"),
        }
    )
end

function dino_green.new_choreography(): Choreography
    local self: DinoGreenLesson = setmetatable({}, {__index = DinoGreenLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function DinoGreenLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE)
    self.walker.speed = WALKER_SPEED
    self.phase = "mounting"
    return {self.walker}
end

function DinoGreenLesson:_has_walked_to(tile: Point, margin?: number): boolean
    return self.walker.position.x >= tile.x - (margin or 0)
end

function DinoGreenLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function DinoGreenLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function DinoGreenLesson:step(_dt: number)
    if self.phase == "mounting" then
        self.stage:mount_dino(self.walker, "green")
        self.phase = "approaching"
        return
    end

    if self.phase == "approaching" then
        self:_walk("right")
        if self:_has_walked_to(TAKEOFF_TILE, STOP_MARGIN) then
            self.stage:dash_with_dino(self.walker)
            self.phase = "dashing"
        end
        return
    end

    if self.phase == "dashing" then
        self:_stand()
        if self.walker:is_crashed() then
            self.phase = "crashed"
        end
        return
    end

    if self.phase == "crashed" then
        self:_stand()
        if not self.walker:is_stunned() then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return dino_green
