-- Stacks three live bombs at once.

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

-- The pillar-free row.
local WALK_ROW = window.FIRST_ROW + 2
local ENTRY_COLUMN = window.FIRST_COLUMN - 1

local PICKUP_COLUMNS = {
    window.FIRST_COLUMN - 1,
    window.FIRST_COLUMN,
    window.FIRST_COLUMN + 1,
    window.FIRST_COLUMN + 2,
    window.FIRST_COLUMN + 3,
    window.FIRST_COLUMN + 4,
}
local PLANT_COLUMNS = {
    window.LAST_COLUMN - 5,
    window.LAST_COLUMN - 4,
    window.LAST_COLUMN - 3,
    window.LAST_COLUMN - 2,
    window.LAST_COLUMN - 1,
}

local ENTRY_TILE = grid.get_tile_position(ENTRY_COLUMN, WALK_ROW)
local SHELTER_TILE = grid.get_tile_position(window.LAST_COLUMN, window.LAST_ROW)

local START_FIRE = 2
local START_BOMBS = 1
local WALKER_SPEED = 45
local PLAYBACK_RATE = 2
-- Fuses, blasts, a beat.
local CYCLE_LENGTH = 4.5
local WALKER_SPRITE: CharacterName = "honey"

-- Off the walker's path, within blast reach.
local SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(window.LAST_COLUMN - 2, window.FIRST_ROW + 1),
    soft_block_at(window.LAST_COLUMN, window.FIRST_ROW + 1),
    soft_block_at(window.LAST_COLUMN - 2, window.LAST_ROW - 1),
}

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local function bomb_pickup_at(column: integer): ItemDrop
    return item_at(column, WALK_ROW, "bomb")
end

local PLANT_TILES = itertools.map(PLANT_COLUMNS, corridor_tile_at)
local LAST_TILE = corridor_tile_at(window.LAST_COLUMN)
local ITEMS = itertools.map(PICKUP_COLUMNS, bomb_pickup_at)

local type WalkerPhase = enum
    "planting"
    "ducking"
    "watching"
end

local record BombLesson is Choreography
    stage: Stage
    walker: Player
    phase: WalkerPhase
    next_plant: integer
end

local bomb = {}

function bomb.new_scenery(): Scenery
    return scenery.new(settings.map, SOFT_BLOCKS, ITEMS)
end

function bomb.new_choreography(): Choreography
    local self: BombLesson = setmetatable({}, {__index = BombLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function BombLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.walker = drones.bomber(WALKER_SPRITE, ENTRY_TILE, START_BOMBS, START_FIRE)
    self.walker.speed = WALKER_SPEED
    self.phase = "planting"
    self.next_plant = 1
    return {self.walker}
end

function BombLesson:_has_walked_to(tile: Point): boolean
    return self.walker.position.x >= tile.x
end

function BombLesson:_has_ducked_to(tile: Point): boolean
    return self.walker.position.y >= tile.y
end

function BombLesson:_walk(direction: Direction)
    self.stage:set_player_inputs(self.walker, {direction})
end

function BombLesson:_stand()
    self.stage:set_player_inputs(self.walker, {})
end

function BombLesson:step(_dt: number)
    if self.phase == "planting" then
        self:_walk("right")
        if self:_has_walked_to(PLANT_TILES[self.next_plant]) then
            self.stage:place_bomb(self.walker)
            self.next_plant = self.next_plant + 1
            if self.next_plant > #PLANT_TILES then
                self.phase = "ducking"
            end
        end
        return
    end

    if self.phase == "ducking" then
        if self:_has_walked_to(LAST_TILE) then
            self:_walk("down")
        end
        if self:_has_ducked_to(SHELTER_TILE) then
            self.phase = "watching"
        end
        return
    end

    self:_stand()
end

return bomb
