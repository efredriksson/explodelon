-- The fire lesson: a bomber lays a bomb, crosses the corridor collecting fires,
-- lays a second, and ducks clear before either blows.

local characters = require("characters")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local itertools = require("itertools")
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
local type ItemDrop = scenery.ItemDrop
local type Player = players.Player
local type Point = points.Point
local type Scenery = scenery.Scenery
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type Stage = choreography.Stage

local soft_block_at = scenery.soft_block_at
local item_at = scenery.item_at

-- Even row (no pillars); odd rows either side have pillars that catch a corridor
-- blast.
local WALK_ROW = window.FIRST_ROW + 2
local ENTRY_COLUMN = window.FIRST_COLUMN - 1

-- Off the window's first column, so the blast stub stays in frame.
local FIRST_BOMB_COLUMN = window.FIRST_COLUMN + 1
local FIRE_COLUMNS = {
    FIRST_BOMB_COLUMN + 1,
    FIRST_BOMB_COLUMN + 2,
}
local SECOND_BOMB_COLUMN = FIRE_COLUMNS[#FIRE_COLUMNS]

-- Two rows below the corridor, out of the second blast's arm row and the bomb's
-- column.
local SHELTER_COLUMN = window.LAST_COLUMN
local SHELTER_ROW = window.LAST_ROW

local ENTRY_TILE = grid.get_tile_position(ENTRY_COLUMN, WALK_ROW)
local FIRST_BOMB_TILE = grid.get_tile_position(FIRST_BOMB_COLUMN, WALK_ROW)
local SECOND_BOMB_TILE = grid.get_tile_position(SECOND_BOMB_COLUMN, WALK_ROW)
local CORRIDOR_END_TILE = grid.get_tile_position(SHELTER_COLUMN, WALK_ROW)
local SHELTER_TILE = grid.get_tile_position(SHELTER_COLUMN, SHELTER_ROW)

-- One, not a battle's two: keeps the blasts a stub against a bar.
local START_FIRE = 1
local START_BOMBS = 2

-- Below battle speed; short corridor and doubled playback would outrun the eye.
local WALKER_SPEED = 45

-- Both fuses, both blasts, a beat, then loop.
local CYCLE_LENGTH = 4.9

-- The walk between bombs is dead air at battle speed.
local PLAYBACK_RATE = 2

local WALKER_SPRITE: CharacterName = "milon"

local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(13, 6),
    soft_block_at(16, 6),
    soft_block_at(12, 10),
    soft_block_at(15, 10),
}

local function fire_pickup_at(column: integer): ItemDrop
    return item_at(column, WALK_ROW, "fire")
end

local ITEMS = itertools.map(FIRE_COLUMNS, fire_pickup_at)

local type WalkerPhase = enum
    "entering"
    "collecting"
    "leaving"
    "ducking"
    "watching"
end

local record FireLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
end

local fire = {}

-- Runs on the map the picker settled on, matching the background.
function fire.new_scenery(): Scenery
    return scenery.new(settings.map, SOFT_BLOCKS, ITEMS)
end

function fire.new_choreography(): Choreography
    local self: FireLesson = setmetatable({}, {__index = FireLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function FireLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE, START_BOMBS, START_FIRE)
    self.walker.speed = WALKER_SPEED
    self.phase = "entering"
    return {self.walker}
end

function FireLesson:_has_walked_to(tile: Point): boolean
    return self.walker.position.x >= tile.x
end

function FireLesson:_has_ducked_to(tile: Point): boolean
    return self.walker.position.y >= tile.y
end

function FireLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function FireLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function FireLesson:step(_dt: number)
    if self.phase == "entering" then
        self:_walk("right")
        if self:_has_walked_to(FIRST_BOMB_TILE) then
            self.stage:place_bomb(self.walker)
            self.phase = "collecting"
        end
        return
    end

    if self.phase == "collecting" then
        self:_walk("right")
        if self:_has_walked_to(SECOND_BOMB_TILE) then
            self.stage:place_bomb(self.walker)
            self.phase = "leaving"
        end
        return
    end

    if self.phase == "leaving" then
        self:_walk("right")
        if self:_has_walked_to(CORRIDOR_END_TILE) then
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

    -- Against the corner it would otherwise stride in place.
    self:_stand()
end

return fire
