-- Kick one bomb into another.

local characters = require("characters")
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

local type CharacterName = characters.CharacterName
local type Choreography = choreography.Choreography
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point
local type Scenery = scenery.Scenery
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type Stage = choreography.Stage

local soft_block_at = scenery.soft_block_at
local item_at = scenery.item_at

local WALK_ROW = window.FIRST_ROW + 2
local ENTRY_COLUMN = window.FIRST_COLUMN - 1

local TARGET_COLUMN = window.FIRST_COLUMN + 1
local KICK_ITEM_COLUMN = window.FIRST_COLUMN + 2
local KICK_BOMB_COLUMN = window.FIRST_COLUMN + 4
local STEP_OFF_COLUMN = window.FIRST_COLUMN + 5
local SHELTER_COLUMN = window.FIRST_COLUMN + 3

local START_FIRE = 4
local START_BOMBS = 2
local WALKER_SPEED = 45
local PLAYBACK_RATE = 2
local CYCLE_LENGTH = 3.5
local WALKER_SPRITE: CharacterName = "kinu"

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local TARGET_TILE = corridor_tile_at(TARGET_COLUMN)
local KICK_BOMB_TILE = corridor_tile_at(KICK_BOMB_COLUMN)
local STEP_OFF_TILE = corridor_tile_at(STEP_OFF_COLUMN)
local SHELTER_TILE = grid.get_tile_position(SHELTER_COLUMN, window.LAST_ROW)

local ITEMS = {
    item_at(KICK_ITEM_COLUMN, WALK_ROW, "kick"),
}

-- Off the walker's path, within blast reach.
local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(TARGET_COLUMN, window.FIRST_ROW + 1),
    soft_block_at(TARGET_COLUMN, window.LAST_ROW - 1),
}

local type WalkerPhase = enum
    "entering"
    "fetching"
    "stepping_off"
    "kicking"
    "ducking"
    "watching"
end

local record KickLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
end

local kick = {}

function kick.new_scenery(): Scenery
    return scenery.new(settings.map, SOFT_BLOCKS, ITEMS)
end

function kick.new_choreography(): Choreography
    local self: KickLesson = setmetatable({}, {__index = KickLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function KickLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE, START_BOMBS, START_FIRE)
    self.walker.speed = WALKER_SPEED
    self.phase = "entering"
    return {self.walker}
end

function KickLesson:_has_walked_to(tile: Point): boolean
    return self.walker.position.x >= tile.x
end

function KickLesson:_has_retreated_to(tile: Point): boolean
    return self.walker.position.x <= tile.x
end

function KickLesson:_has_ducked_to(tile: Point): boolean
    return self.walker.position.y >= tile.y
end

function KickLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function KickLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function KickLesson:step(_dt: number)
    if self.phase == "entering" then
        self:_walk("right")
        if self:_has_walked_to(TARGET_TILE) then
            self.stage:place_bomb(self.walker)
            self.phase = "fetching"
        end
        return
    end

    if self.phase == "fetching" then
        self:_walk("right")
        if self:_has_walked_to(KICK_BOMB_TILE) then
            self.stage:place_bomb(self.walker)
            self.phase = "stepping_off"
        end
        return
    end

    if self.phase == "stepping_off" then
        self:_walk("right")
        if self:_has_walked_to(STEP_OFF_TILE) then
            self.phase = "kicking"
        end
        return
    end

    if self.phase == "kicking" then
        self:_walk("left")
        if self:_has_retreated_to(SHELTER_TILE) then
            self.phase = "ducking"
        end
        return
    end

    if self.phase == "ducking" then
        self:_walk("down")
        if self:_has_ducked_to(SHELTER_TILE) then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return kick
