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

local BOMB_COLUMN = window.LAST_COLUMN

-- Low, so each pickup reads.
local START_SPEED = 30
local PLAYBACK_RATE = 2
local CYCLE_LENGTH = 4.2
local WALKER_SPRITE: CharacterName = "kotetsu"

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local ENTRY_TILE = corridor_tile_at(ENTRY_COLUMN)
local BOMB_TILE = corridor_tile_at(BOMB_COLUMN)
local SHELTER_TILE = grid.get_tile_position(BOMB_COLUMN, window.LAST_ROW)

local ITEMS = {
    item_at(window.FIRST_COLUMN + 2, WALK_ROW, "speed"),
    item_at(window.FIRST_COLUMN + 3, WALK_ROW, "speed"),
    item_at(window.FIRST_COLUMN + 4, WALK_ROW, "speed"),
    item_at(window.FIRST_COLUMN + 5, WALK_ROW, "speed"),
    item_at(window.FIRST_COLUMN + 5, WALK_ROW + 1, "speed"),
}

-- Off the walker's path, within blast reach.
local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(window.LAST_COLUMN, window.FIRST_ROW + 1),
}

local type WalkerPhase = enum
    "crossing"
    "ducking"
    "loopback"
end

local record SpeedLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
end

local speed = {}

function speed.new_scenery(): Scenery
    return scenery.new(settings.map, SOFT_BLOCKS, ITEMS)
end

function speed.new_choreography(): Choreography
    local self: SpeedLesson = setmetatable({}, {__index = SpeedLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function SpeedLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE)
    self.walker.speed = START_SPEED
    self.phase = "crossing"
    return {self.walker}
end

function SpeedLesson:_has_walked_to(tile: Point): boolean
    return self.walker.position.x >= tile.x
end

function SpeedLesson:_has_ducked_to(tile: Point): boolean
    return self.walker.position.y >= tile.y
end

function SpeedLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function SpeedLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function SpeedLesson:step(_dt: number)
    if self.phase == "crossing" then
        self:_walk("right")
        if self:_has_walked_to(BOMB_TILE) then
            self.stage:place_bomb(self.walker)
            self.phase = "ducking"
        end
        return
    end

    if self.phase == "ducking" then
        self:_walk("down")
        if self:_has_ducked_to(SHELTER_TILE) then
            self.phase = "loopback"
        end
        return
    end

    if self.phase == "loopback" then
        self:_walk("left")
        return
    end

    self:_stand()
end

return speed
