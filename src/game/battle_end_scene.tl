require("characters")
local audio = require("engine.audio")
local scenes = require("engine.scenes")
local settings = require("settings")
local winner_scene = require("game.winner_scene")


local winner_sound: Source
local draw_sound: Source
local time_up_sound: Source
local battle_end_scene = {}

local record BattleEndScene is Scene
    game_scene: Scene
    next_scene: Scene
    played_sound: boolean
    sound: Source
    scene_lenght: number
    time: number
end

function BattleEndScene.new(
    game_scene: Scene, next_scene: Scene, sound: Source, scene_lenght: number
): BattleEndScene
    local self: BattleEndScene = setmetatable({}, { __index = BattleEndScene })
    self.game_scene = game_scene
    self.next_scene = next_scene
    self.played_sound = false
    self.sound = sound
    self.time = 0
    self.scene_lenght = scene_lenght
    return self
end

function battle_end_scene.new_for_winner(
    game_scene: Scene, name: CharacterName, score: integer
): BattleEndScene
    local function get_next_scene(): Scene
        if score < settings.game_rules.timings.nbr_battles then
            return game_scene
        else
            return winner_scene.new(name)
        end
    end
    return BattleEndScene.new(game_scene, get_next_scene(), winner_sound, 3)
end

function battle_end_scene.new_for_draw(
    game_scene: Scene
): BattleEndScene
    return BattleEndScene.new(game_scene, game_scene, draw_sound, 4)
end

function battle_end_scene.new_for_timeout(
    game_scene: Scene
): BattleEndScene
    return BattleEndScene.new(game_scene, game_scene, time_up_sound, 2)
end

function battle_end_scene.load_assets()
    winner_sound = audio.new_source("assets/battle-end.ogg", "static")
    draw_sound = audio.new_source("assets/battle-draw.ogg", "static")
    time_up_sound = audio.new_source("assets/battle-time-up.wav", "static")
    winner_scene.load_assets()
end

function BattleEndScene:draw()
	self.game_scene:draw()
end

function BattleEndScene:update(dt: number)
    self.game_scene:update(dt)

    if not self.played_sound then
        self.played_sound = true
        self.sound:play()
    end

    self.time = self.time + dt
    if self.time > self.scene_lenght then
        audio.stop()
        scenes.set(self.next_scene)
    end
end

return battle_end_scene
