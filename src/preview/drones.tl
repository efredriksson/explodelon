-- The scripted actors a map preview drive.

local characters = require("characters")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local players = require("players")
local choreography = require("preview.choreography")
local settings = require("settings")

local type CharacterName = characters.CharacterName
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point
local type Stage = choreography.Stage

local BOMBER_SPRITE: CharacterName = "kotetsu"
local VICTIM_SPRITE: CharacterName = "white"
local BYSTANDER_SPRITE: CharacterName = "black"

local OPPOSITE: {Direction: Direction} = {
    up = "down",
    down = "up",
    left = "right",
    right = "left",
}

local record Pacer
    walker: Player
    origin: Point
    reach: number
    facing: Direction
end

-- Walking back into a bomb it just laid is what kicks it.
local KICK_DIRECTION: Direction = "left"
local STEP_OFF_DIRECTION = OPPOSITE[KICK_DIRECTION]
local STEP_OFF_DISTANCE = 20
local RETURN_MARGIN = 1.75

local type KickPhase = enum
    "placing"
    "stepping_off"
    "returning"
    "retreating"
    "resting"
end

local record KickCycle
    kicker: Player
    origin: Point
    bomb_budget: integer
    escape: Direction
    escape_distance: number
    rest_duration: number

    phase: KickPhase
    bombs_placed: integer
    rest_left: number
end

local drones = {KickCycle = KickCycle, Pacer = Pacer}

local function new_bomber(start: Point, bomb_count: integer, fire: integer): Player
    local drone = players.new(1, BOMBER_SPRITE, start)
    drone.bombs = bomb_count
    drone.fire = fire
    return drone
end

function drones.kicker(start: Point, bomb_count: integer, fire: integer): Player
    local drone = new_bomber(start, bomb_count, fire)
    drone.has_kick = true
    return drone
end

function drones.bomber(start: Point, bomb_count: integer, fire: integer): Player
    return new_bomber(start, bomb_count, fire)
end

function drones.victim(start: Point): Player
    local drone = players.new(2, VICTIM_SPRITE, start)
    local grace = settings.game_rules.players.petrify_grace_seconds
    drone.time_alive = grace + 1 -- Nudged past the grace window so victim can die
    return drone
end

function drones.bystander(start: Point): Player
    return players.new(3, BYSTANDER_SPRITE, start)
end

function Pacer.new(walker: Player, reach: number, facing: Direction): Pacer
    local self: Pacer = setmetatable({}, {__index = Pacer})
    self.walker = walker
    self.origin = walker.position
    self.reach = reach
    self.facing = facing
    return self
end

function Pacer:_turn()
    self.facing = OPPOSITE[self.facing]
end

function Pacer:_direction(): Direction
    local heading = vectors.from_direction(self.facing)
    -- Projected onto the heading so it turns once, not every frame out of reach.
    local travelled = self.origin:vector_to(self.walker.position):dot_product(heading)
    if travelled >= self.reach then
        self:_turn()
    end
    return self.facing
end

function Pacer:steer(stage: Stage)
    stage:set_player_inputs(self.walker, {self:_direction()})
end

function KickCycle.new(
    kicker: Player,
    bomb_budget: integer,
    escape: Direction,
    escape_distance: number,
    rest_duration?: number
): KickCycle
    local self: KickCycle = setmetatable({}, {__index = KickCycle})
    self.kicker = kicker
    self.origin = kicker.position
    self.bomb_budget = bomb_budget
    self.escape = escape
    self.escape_distance = escape_distance
    self.rest_duration = rest_duration or 0
    self.phase = "placing"
    self.bombs_placed = 0
    self.rest_left = 0
    return self
end

function KickCycle:_distance_from_origin(): number
    return self.kicker.position:distance_to(self.origin)
end

function KickCycle:_place(stage: Stage)
    stage:place_bomb(self.kicker)
    self.bombs_placed = self.bombs_placed + 1
    stage:set_player_inputs(self.kicker, {})
    self.phase = "stepping_off"
end

function KickCycle:_step_off(stage: Stage)
    stage:set_player_inputs(self.kicker, {STEP_OFF_DIRECTION})
    if self:_distance_from_origin() >= STEP_OFF_DISTANCE then
        self.phase = "returning"
    end
end

function KickCycle:_return(stage: Stage)
    stage:set_player_inputs(self.kicker, {KICK_DIRECTION})
    if self:_distance_from_origin() > RETURN_MARGIN then
        return
    end

    if self.bombs_placed >= self.bomb_budget then
        self.phase = "retreating"
    else
        self.phase = "resting"
        self.rest_left = self.rest_duration
    end
end

function KickCycle:_retreat(stage: Stage)
    stage:set_player_inputs(self.kicker, {self.escape})
    if self:_distance_from_origin() >= self.escape_distance then
        self.phase = "resting"
    end
end

function KickCycle:_rest(stage: Stage, dt: number)
    stage:set_player_inputs(self.kicker, {})
    self.rest_left = self.rest_left - dt
    if self.rest_left <= 0 and self.bombs_placed < self.bomb_budget then
        self.phase = "placing"
    end
end

function KickCycle:steer(stage: Stage, dt: number)
    if self.phase == "placing" then
        self:_place(stage)
    elseif self.phase == "stepping_off" then
        self:_step_off(stage)
    elseif self.phase == "returning" then
        self:_return(stage)
    elseif self.phase == "retreating" then
        self:_retreat(stage)
    elseif self.phase == "resting" then
        self:_rest(stage, dt)
    end
end

return drones
