-- One looping set piece: how long a run lasts, and its drones' part frame by frame.

local vectors = require("engine.geometry.vectors")
local players = require("players")

local type Direction = vectors.Direction
local type Player = players.Player
local type Vector = vectors.Vector

local type Stage = interface
    set_player_inputs: function(self, player: Player, directions: {Direction})
    place_bomb: function(self, player: Player)
    face: function(self, player: Player, direction: Direction)
    slide: function(self, player: Player, velocity: Vector)
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
