local character_sprites = require("character_sprites")
local const = require("const")
local fonts = require("fonts")
local points = require("geometry.points")
local vectors = require("geometry.vectors")


local score_font: ShadedFont
local avatar_images: {CharacterSprite: Image}

global record PlayerScore
    id: integer
    score: integer
    avatar: CharacterSprite
end

function PlayerScore.new(id: integer, avatar: CharacterSprite): PlayerScore
    local self: PlayerScore = setmetatable({}, { __index = PlayerScore })
    self.id = id
    self.score = 0
    self.avatar = avatar
    return self
end

global record ScoreBoard
    players: {PlayerScore}
end

local score_board = {}

function score_board.new(avatars: {CharacterSprite}): ScoreBoard
    local self: ScoreBoard = setmetatable({}, { __index = ScoreBoard })
    self.players = {}
    for id, avatar in ipairs(avatars) do
        table.insert(self.players, PlayerScore.new(id, avatar))
    end
    return self
end

local function get_avatar_position(avatar_num: number, num_avatars: number): Point
	local space_for_avatar = 35
	local x_start = 75
	local y_start = 3
	local avatar_space_padding = 10

	local total_space = const.MAP_WIDTH - x_start - avatar_space_padding
	local padding = (total_space - space_for_avatar * num_avatars) / (num_avatars + 1)
	local x_pos = x_start + padding * avatar_num + space_for_avatar * (avatar_num - 1)
	return points.new(x_pos, y_start)
end

function ScoreBoard:draw()
    for _, player in ipairs(self.players) do
		local avatar_pos = get_avatar_position(player.id, #self.players)
		local score_pos = avatar_pos:move(vectors.new(18, 5))
		lutro.graphics.draw(avatar_images[player.avatar], avatar_pos.x, avatar_pos.y)
		score_font:draw(tostring(player.score), score_pos)
	end
end

function ScoreBoard:add_point(player_id: integer)
    for _, player in ipairs(self.players) do
        if player.id == player_id then
            player.score = player.score + 1
            return
        end
    end

    assert(false, "Trying to set score for missing player!")
end

function ScoreBoard:update_avatars(new_sprites: {CharacterSprite})
    local old_data = self.players
    self.players = {}
    for id, sprite in ipairs(new_sprites) do
        local new_player = PlayerScore.new(id, sprite)
        for _, old_player in ipairs(old_data) do
            if old_player.avatar == new_player.avatar then
                new_player.score = old_player.score
            end
        end

        table.insert(self.players, new_player)
    end
end

function ScoreBoard.load_assets()
    score_font = fonts.new_shaded_numbers()
    avatar_images = {}
    for _, sprite in ipairs(character_sprites.get()) do
        avatar_images[sprite] = lutro.graphics.newImage(
            "assets/" .. sprite .. "/head_down.png"
        )
    end
end

return score_board
