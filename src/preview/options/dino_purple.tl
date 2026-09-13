-- The purple dino lesson: sonic blast clearing a bomb up close.

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

local RIDER_ENTRY_COLUMN = window.FIRST_COLUMN - 1
local BOMB_COLUMN = window.FIRST_COLUMN + 3
local CRY_COLUMN = BOMB_COLUMN - 2

local BOMB_FIRE = 4

local RIDER_SPEED = 40
local STOP_MARGIN = 1
local PLAYBACK_RATE = 2
local CYCLE_LENGTH = 4.0
local RIDER_SPRITE: CharacterName = "manjimaru"

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local RIDER_ENTRY_TILE = corridor_tile_at(RIDER_ENTRY_COLUMN)
local CRY_TILE = corridor_tile_at(CRY_COLUMN)
local SCENERY_BOMBS = {
    scenery.bomb_at(BOMB_COLUMN, WALK_ROW, BOMB_FIRE),
}
local SCENERY_ITEMS = {
    scenery.item_at(BOMB_COLUMN - 1, WALK_ROW, "speed"),
}

local type RiderPhase = enum
    "mounting"
    "approaching"
    "roaring"
    "watching"
end

local record DinoPurpleLesson is Choreography
    stage: Stage
    rider: Player
    rider_phase: RiderPhase
end

local dino_purple = {}

function dino_purple.new_scenery(): Scenery
    return scenery.new(settings.map, {}, SCENERY_ITEMS, nil, SCENERY_BOMBS)
end

function dino_purple.new_choreography(): Choreography
    local self: DinoPurpleLesson = setmetatable({}, {__index = DinoPurpleLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function DinoPurpleLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.rider = drones.bystander(RIDER_SPRITE, RIDER_ENTRY_TILE)
    self.rider.speed = RIDER_SPEED
    self.rider_phase = "mounting"
    return {self.rider}
end

function DinoPurpleLesson:_has_advanced_to(tile: Point, margin?: number): boolean
    return self.rider.position.x >= tile.x - (margin or 0)
end

function DinoPurpleLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.rider, {direction})
end

function DinoPurpleLesson:_stand()
    self.stage:set_player_inputs(self.rider, {})
end

function DinoPurpleLesson:_step_rider()
    if self.rider_phase == "mounting" then
        self.stage:mount_dino(self.rider, "purple")
        self.rider_phase = "approaching"
        return
    end

    if self.rider_phase == "approaching" then
        self:_walk("right")
        if self:_has_advanced_to(CRY_TILE, STOP_MARGIN) then
            self.stage:sonic_blast_with_dino(self.rider)
            self.rider_phase = "roaring"
        end
        return
    end

    if self.rider_phase == "roaring" then
        self:_stand()
        if not self.rider:is_roaring() then
            self.rider_phase = "watching"
        end
        return
    end

    self:_stand()
end

function DinoPurpleLesson:step(_dt: number)
    self:_step_rider()
end

return dino_purple
