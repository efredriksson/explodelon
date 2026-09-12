-- One looping set piece: how long a run lasts, and its drones' part frame by frame.

local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local players = require("players")
local settings = require("settings")

local type DinoColor = settings.DinoColor
local type Direction = vectors.Direction
local type Player = players.Player
local type Point = points.Point
local type Vector = vectors.Vector

local type Stage = interface
    set_player_inputs: function(self, player: Player, directions: {Direction})
    place_bomb: function(self, player: Player)
    place_lightning_bomb: function(self, player: Player)
    face: function(self, player: Player, direction: Direction)
    slide: function(self, player: Player, velocity: Vector)
    mount_dino: function(self, player: Player, color: DinoColor)
    throw_bomb_with_dino: function(self, player: Player, to: Point)
    jump_with_dino: function(self, player: Player, to: Point)
end

-- open() runs once per run: spawn a fresh cast, clear phase state.
local type Choreography = interface
    cycle_length: number
    playback_rate: integer

    open: function(self, stage: Stage): {Player}
    step: function(self, dt: number)
end

local choreography = {
    Choreography = Choreography,
    Stage = Stage,
}

return choreography
