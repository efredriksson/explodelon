local characters = require("characters")
local fonts = require("fonts")
local images = require("engine.images")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local screen = require("screen")
local settings = require("settings")

local type CharacterName = characters.CharacterName
local type CharacterSelection = characters.CharacterSelection
local type Color = images.Color
local type ShadedFont = fonts.ShadedFont
local type Point = points.Point

local score_font: ShadedFont
local avatar_images: {CharacterName: Image}

local interface ScoreBoard
    draw: function(self)
    add_point: function(self, id: integer)
    game_finished: function(self): boolean
    remove_player: function(self, player_id: integer)
end

local record PlayerScore
    id: integer
    score: integer
    avatar: CharacterName
end

local record SinglesScoreBoard is ScoreBoard
    players: {PlayerScore}
end

local record TeamScore
    team_id: integer
    color: Color
    score: integer
    avatars: {CharacterName}
end

local record TeamsScoreBoard is ScoreBoard
    teams: {TeamScore}
end

local score_board = {ScoreBoard = ScoreBoard, SinglesScoreBoard = SinglesScoreBoard, TeamsScoreBoard = TeamsScoreBoard}

function PlayerScore.new(id: integer, avatar: CharacterName): PlayerScore
    local self: PlayerScore = setmetatable({}, { __index = PlayerScore })
    self.id = id
    self.score = 0
    self.avatar = avatar
    return self
end

local function get_avatar_position(avatar_num: number, num_avatars: number): Point
	local space_for_avatar = 35
	local x_start = 75
	local y_start = 3
	local avatar_space_padding = 10

	local total_space = screen.WIDTH - x_start - avatar_space_padding
	local padding = (total_space - space_for_avatar * num_avatars) / (num_avatars + 1)
	local x_pos = x_start + padding * avatar_num + space_for_avatar * (avatar_num - 1)
	return points.new(x_pos, y_start)
end

function SinglesScoreBoard:draw()
    for nbr, player in ipairs(self.players) do
		local avatar_pos = get_avatar_position(nbr, #self.players)
		local score_pos = avatar_pos:move(vectors.new(18, 5))
		lutro.graphics.draw(avatar_images[player.avatar], avatar_pos.x, avatar_pos.y)
		score_font:draw(tostring(player.score), score_pos)
	end
end

function SinglesScoreBoard:add_point(player_id: integer)
    for _, player in ipairs(self.players) do
        if player.id == player_id then
            player.score = player.score + 1
            return
        end
    end
    assert(false, "Trying to set score for missing player!")
end

function SinglesScoreBoard:update_avatars(new_characters: {CharacterSelection})
    local old_data = self.players
    self.players = {}
    for _, char in ipairs(new_characters) do
        local new_player = PlayerScore.new(char.player_id, char.sprite)
        for _, old_player in ipairs(old_data) do
            if old_player.id == new_player.id then
                new_player.score = old_player.score
            end
        end
        table.insert(self.players, new_player)
    end
end

function SinglesScoreBoard:remove_player(player_id: integer)
    for i, player in ipairs(self.players) do
        if player.id == player_id then
            table.remove(self.players, i)
            return
        end
    end
end

function SinglesScoreBoard:game_finished(): boolean
    for _, player in ipairs(self.players) do
        if player.score >= settings.game_rules.timings.nbr_battles then
            return true
        end
    end
    return false
end

function score_board.new_for_singles(): SinglesScoreBoard
    local self: SinglesScoreBoard = setmetatable({}, { __index = SinglesScoreBoard })
    self.players = {}
    return self
end

local TEAM_COLORS: {integer: Color} = {
    [1] = {220, 50, 50},
    [2] = {50, 80, 220},
    [3] = {50, 180, 50},
    [4] = {220, 200, 50},
}

local COLOR_BLOCK_SIZE<const> = 16
local AVATAR_WIDTH<const> = 16

function TeamsScoreBoard:_get_team_width(team: TeamScore): number
    -- color block + score + avatars
    return COLOR_BLOCK_SIZE + 18 + AVATAR_WIDTH * #team.avatars
end

function TeamsScoreBoard:draw()
    local x_start = 75
    local y_start = 3
    local team_gap = 12

    local total_width: number = 0
    for _, team in ipairs(self.teams) do
        total_width = total_width + self:_get_team_width(team)
    end
    total_width = total_width + team_gap * (#self.teams - 1)

    local available = screen.WIDTH - x_start - 10
    local x = x_start + (available - total_width) / 2

    for _, team in ipairs(self.teams) do
        local r, g, b = table.unpack(team.color)
        lutro.graphics.setColor(r, g, b)
        lutro.graphics.rectangle("fill", x, y_start, COLOR_BLOCK_SIZE, COLOR_BLOCK_SIZE)
        lutro.graphics.setColor(255, 255, 255)
        x = x + COLOR_BLOCK_SIZE
        local score_pos = points.new(x + 2, y_start + 5)
        score_font:draw(tostring(team.score), score_pos)
        x = x + 18
        for _, avatar in ipairs(team.avatars) do
            lutro.graphics.draw(avatar_images[avatar], x, y_start)
            x = x + AVATAR_WIDTH
        end
        x = x + team_gap
    end
end

function TeamsScoreBoard:add_point(team_id: integer)
    for _, team in ipairs(self.teams) do
        if team.team_id == team_id then
            team.score = team.score + 1
            return
        end
    end
    assert(false, "Trying to set score for missing team!")
end

function TeamsScoreBoard:game_finished(): boolean
    for _, team in ipairs(self.teams) do
        if team.score >= settings.game_rules.timings.nbr_battles then
            return true
        end
    end
    return false
end

function TeamsScoreBoard:update_avatars(avatars_by_team: {integer: {CharacterSelection}})
    for team_id, selections in pairs(avatars_by_team) do
        local avatars: {CharacterName} = {}
        for _, sel in ipairs(selections) do
            table.insert(avatars, sel.sprite)
        end
        table.insert(self.teams, {
            team_id = team_id,
            color = TEAM_COLORS[team_id] or {128, 128, 128},
            score = 0,
            avatars = avatars,
        })
    end
end

function score_board.new_for_teams(): TeamsScoreBoard
    local self: TeamsScoreBoard = setmetatable({}, { __index = TeamsScoreBoard })
    self.teams = {}
    return self
end

function score_board.load_assets()
    score_font = fonts.new_shaded_numbers()
    avatar_images = {}
    for _, sprite in ipairs(characters.get_names()) do
        avatar_images[sprite] = lutro.graphics.newImage(
            "assets/" .. sprite .. "/head_down.png"
        )
    end
end

return score_board
