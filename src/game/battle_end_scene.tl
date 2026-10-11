local characters = require("characters")
local audio = require("engine.audio")
local scenes = require("engine.scenes")
local score_board = require("game.score_board")
local winner_scene = require("game.winner_scene")
local settings = require("settings")

local type CharacterName = characters.CharacterName
local type Scene = scenes.Scene
local type ScoreBoard = score_board.ScoreBoard

-- From the battle being decided until the winner is heard. The last 0.4 s are
-- silence that the cheer starts with and the sound file leaves out.
local WINNER_CHEERS_AFTER = 91 / 60 + 0.4

local decided_sound: Source
local winner_cheer_sound: Source
local time_up_sound: Source
local battle_end_scene = {}

local record Cue
    sound: Source
    at: number
end

function Cue.new(sound: Source, at: number): Cue
    local self: Cue = setmetatable({}, {__index = Cue})
    self.sound = sound
    self.at = at
    return self
end

local record BattleEndScene is Scene
    game_scene: Scene
    next_scene: Scene
    cues: {Cue}
    scene_lenght: number
    time: number
end

function BattleEndScene.new(
    game_scene: Scene, next_scene: Scene, cues: {Cue}, scene_lenght: number
): BattleEndScene
    local self: BattleEndScene = setmetatable({}, {__index = BattleEndScene})
    self.game_scene = game_scene
    self.next_scene = next_scene
    self.cues = cues
    self.time = 0
    self.scene_lenght = scene_lenght
    return self
end

function battle_end_scene.new_for_winners(
    game_scene: Scene, names: {CharacterName}, score_board_: ScoreBoard
): BattleEndScene
    local function get_next_scene(): Scene
        if score_board_:game_finished() then
            settings.remember_game_finished()
            return winner_scene.new(names)
        else
            return game_scene
        end
    end
    local cues = {
        Cue.new(decided_sound, 0),
        Cue.new(winner_cheer_sound, WINNER_CHEERS_AFTER),
    }
    return BattleEndScene.new(game_scene, get_next_scene(), cues, 3)
end

function battle_end_scene.new_for_draw(game_scene: Scene): BattleEndScene
    return BattleEndScene.new(game_scene, game_scene, {Cue.new(decided_sound, 0)}, 4)
end

function battle_end_scene.new_for_timeout(game_scene: Scene): BattleEndScene
    return BattleEndScene.new(game_scene, game_scene, {Cue.new(time_up_sound, 0)}, 2)
end

function battle_end_scene.load_assets()
    decided_sound = audio.new_source("assets/sfx/battle_decided.wav", "static")
    winner_cheer_sound = audio.new_source("assets/sfx/winner_cheer.wav", "static")
    time_up_sound = audio.new_source("assets/sfx/time_up.wav", "static")
    winner_scene.load_assets()
end

function BattleEndScene:draw()
    self.game_scene:draw()
end

function BattleEndScene:update(dt: number)
    self.game_scene:update(dt)

    for i = #self.cues, 1, -1 do
        if self.time >= self.cues[i].at then
            self.cues[i].sound:play()
            table.remove(self.cues, i)
        end
    end

    self.time = self.time + dt
    if self.time > self.scene_lenght then
        audio.stop()
        scenes.set(self.next_scene)
    end
end

return battle_end_scene
