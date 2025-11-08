local audio = require("audio")
local scenes = require("scenes")


local winner_sound: Source
local draw_sound: Source
local time_up_sound: Source
local game_end = {}

local record GameEnd is Scene
    game_scene: Scene
    played_sound: boolean
    sound: Source
    scene_lenght: number
    time: number
end

function GameEnd.new(
    game_scene: Scene, sound: Source, scene_lenght: number
): GameEnd
    local self: GameEnd = setmetatable({}, { __index = GameEnd })
    self.game_scene = game_scene
    self.played_sound = false
    self.sound = sound
    self.time = 0
    self.scene_lenght = scene_lenght
    return self
end

function game_end.new_for_winner(
    game_scene: Scene
): GameEnd
    return GameEnd.new(game_scene, winner_sound, 3)
end

function game_end.new_for_draw(
    game_scene: Scene
): GameEnd
    return GameEnd.new(game_scene, draw_sound, 4)
end

function game_end.new_for_timeout(
    game_scene: Scene
): GameEnd
    return GameEnd.new(game_scene, time_up_sound, 2)
end

function game_end.load_assets()
    winner_sound = audio.new_source("assets/battle-end.ogg", "static")
    draw_sound = audio.new_source("assets/battle-draw.ogg", "static")
    time_up_sound = audio.new_source("assets/battle-time-up.wav", "static")
end

function GameEnd:draw()
	self.game_scene:draw()
end

function GameEnd:update(dt: number)
    self.game_scene:update(dt)

    if not self.played_sound then
        self.played_sound = true
        self.sound:play()
    end

    self.time = self.time + dt
    if self.time > self.scene_lenght then
        scenes.set(self.game_scene)
    end
end

return game_end
