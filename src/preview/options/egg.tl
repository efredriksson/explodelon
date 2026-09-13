-- Hatch it, then ride out.

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
local EGG_COLUMN = window.FIRST_COLUMN + 3

local WALKER_SPEED = 45
local PLAYBACK_RATE = 2
local CYCLE_LENGTH = 4
local WALKER_SPRITE: CharacterName = "kabuki"

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local EGG_TILE = corridor_tile_at(EGG_COLUMN)

local type WalkerPhase = enum
    "approaching"
    "leaving"
    "watching"
end

local record EggLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
end

local egg = {}

function egg.new_scenery(): Scenery
    return scenery.new(settings.map, {}, {}, {EGG_TILE})
end

function egg.new_choreography(): Choreography
    local self: EggLesson = setmetatable({}, {__index = EggLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function EggLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE)
    self.walker.speed = WALKER_SPEED
    self.phase = "approaching"
    return {self.walker}
end

function EggLesson:_has_walked_to(tile: Point): boolean
    return self.walker.position.x >= tile.x
end

function EggLesson:_has_retreated_to(tile: Point): boolean
    return self.walker.position.x <= tile.x
end

function EggLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function EggLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function EggLesson:step(_dt: number)
    if self.phase == "approaching" then
        self:_walk("right")
        if self:_has_walked_to(EGG_TILE) then
            self.phase = "leaving"
        end
        return
    end

    if self.phase == "leaving" then
        self:_walk("left")
        if self:_has_retreated_to(ENTRY_TILE) then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return egg
