-- The yellow dino lesson: stun cry bomber mid-lay killing them.

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
local DESCENT_COLUMN = window.LAST_COLUMN

local RIDER_ENTRY_COLUMN = window.FIRST_COLUMN - 1
local STUN_COLUMN = window.FIRST_COLUMN + 1
local TRIGGER_COLUMN = window.LAST_COLUMN - 1

local VICTIM_BOMBS = 2
local VICTIM_FIRE = 3

local WALKER_SPEED = 40
local STOP_MARGIN = 1
local PLAYBACK_RATE = 2
local CYCLE_LENGTH = 4.0

local function corridor_tile_at(column: integer): Point
    return grid.get_tile_position(column, WALK_ROW)
end

local VICTIM_ENTRY_TILE = grid.get_tile_position(DESCENT_COLUMN, window.FIRST_ROW - 1)
local DESCENT_TARGET_TILE = corridor_tile_at(DESCENT_COLUMN)
local RIDER_ENTRY_TILE = corridor_tile_at(RIDER_ENTRY_COLUMN)
local STUN_TILE = corridor_tile_at(STUN_COLUMN)
local TRIGGER_TILE = corridor_tile_at(TRIGGER_COLUMN)
local PLANT_TILES = {
    grid.get_tile_position(window.LAST_COLUMN, window.FIRST_ROW),
    grid.get_tile_position(window.LAST_COLUMN, WALK_ROW),
}

local type VictimPhase = enum
    "descending"
    "approaching"
    "frozen"
end

local type RiderPhase = enum
    "mounting"
    "approaching"
    "waiting"
    "roaring"
    "watching"
end

local record DinoYellowLesson is Choreography
    stage: Stage
    victim: Player
    rider: Player
    victim_phase: VictimPhase
    rider_phase: RiderPhase
    next_plant: integer
end

local dino_yellow = {}

function dino_yellow.new_scenery(): Scenery
    return scenery.new(settings.map, {}, {})
end

function dino_yellow.new_choreography(): Choreography
    local self: DinoYellowLesson = setmetatable({}, {__index = DinoYellowLesson})
    self.cycle_length = CYCLE_LENGTH
    self.playback_rate = PLAYBACK_RATE
    return self
end

function DinoYellowLesson:open(stage: Stage): {Player}
    self.stage = stage
    self.victim = drones.bomber_victim(VICTIM_ENTRY_TILE, VICTIM_BOMBS, VICTIM_FIRE)
    self.victim.speed = WALKER_SPEED
    self.rider = drones.bystander(RIDER_ENTRY_TILE)
    self.rider.speed = WALKER_SPEED
    self.victim_phase = "descending"
    self.rider_phase = "mounting"
    self.next_plant = 1
    return {self.victim, self.rider}
end

function DinoYellowLesson:_has_advanced_to(
    walker: Player, tile: Point, margin?: number
): boolean
    return walker.position.x >= tile.x - (margin or 0)
end

function DinoYellowLesson:_has_retreated_to(
    walker: Player, tile: Point, margin?: number
): boolean
    return walker.position.x <= tile.x + (margin or 0)
end

function DinoYellowLesson:_has_descended_to(
    walker: Player, tile: Point, margin?: number
): boolean
    return walker.position.y >= tile.y - (margin or 0)
end

function DinoYellowLesson:_walk(walker: Player, direction: Direction)
    self.stage:set_player_inputs(walker, {direction})
end

function DinoYellowLesson:_stand(walker: Player)
    self.stage:set_player_inputs(walker, {})
end

function DinoYellowLesson:_step_victim()
    if self.victim_phase == "descending" then
        self:_walk(self.victim, "down")
        if
            self.next_plant <= #PLANT_TILES
            and self:_has_descended_to(
                self.victim, PLANT_TILES[self.next_plant], STOP_MARGIN
            )
        then
            self.stage:place_bomb(self.victim)
            self.next_plant = self.next_plant + 1
        end
        if self:_has_descended_to(self.victim, DESCENT_TARGET_TILE, STOP_MARGIN) then
            self.victim_phase = "approaching"
        end
        return
    end

    if self.victim_phase == "approaching" then
        self:_walk(self.victim, "left")
        if self.victim:is_stunned() then
            self.victim_phase = "frozen"
        end
        return
    end

    self:_stand(self.victim)
end

function DinoYellowLesson:_step_rider()
    if self.rider_phase == "mounting" then
        self.stage:mount_dino(self.rider, "yellow")
        self.rider_phase = "approaching"
        return
    end

    if self.rider_phase == "approaching" then
        self:_walk(self.rider, "right")
        if self:_has_advanced_to(self.rider, STUN_TILE, STOP_MARGIN) then
            self.rider_phase = "waiting"
        end
        return
    end

    if self.rider_phase == "waiting" then
        self:_stand(self.rider)
        if self:_has_retreated_to(self.victim, TRIGGER_TILE) then
            self.stage:stun_cry_with_dino(self.rider)
            self.rider_phase = "roaring"
        end
        return
    end

    if self.rider_phase == "roaring" then
        self:_stand(self.rider)
        if not self.rider:is_roaring() then
            self.rider_phase = "watching"
        end
        return
    end

    self:_stand(self.rider)
end

function DinoYellowLesson:step(_dt: number)
    self:_step_rider()
    self:_step_victim()
end

return dino_yellow
