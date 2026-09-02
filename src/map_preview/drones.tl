-- The scripted actors a map preview drive.

local characters = require("characters")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local players = require("players")
local settings = require("settings")

local type CharacterName = characters.CharacterName
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point

local BOMBER_SPRITE: CharacterName = "kotetsu"
local VICTIM_SPRITE: CharacterName = "white"

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

local drones = {Pacer = Pacer}

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

function drones.victim(start: Point): Player
    local drone = players.new(2, VICTIM_SPRITE, start)
    local grace = settings.game_rules.players.petrify_grace_seconds
    drone.time_alive = grace + 1 -- Nudged past the grace window so victim can die
    return drone
end

function Pacer.new(walker: Player, reach: number, facing: Direction): Pacer
    local self: Pacer = setmetatable({}, {__index = Pacer})
    self.walker = walker
    self.origin = walker.position
    self.reach = reach
    self.facing = facing
    return self
end

function Pacer:turn()
    self.facing = OPPOSITE[self.facing]
end

function Pacer:direction(): Direction
    local heading = vectors.from_direction(self.facing)
    -- Projecting onto the current heading to only turn once when out of reach
    local travelled = self.origin:vector_to(self.walker.position):dot_product(heading)
    if travelled >= self.reach then
        self:turn()
    end
    return self.facing
end

return drones
