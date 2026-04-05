local characters = require("characters")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local images = require("engine.images")
local fonts = require("fonts")
local screen = require("screen")
local settings = require("settings")
local teams = require("teams")

local type CharacterName = characters.CharacterName
local type CharacterSelection = characters.CharacterSelection
local type Color = images.Color
local type ShadedFont = fonts.ShadedFont
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type Team = teams.Team
local type TeamSelection = teams.TeamSelection

local score_font: ShadedFont
local avatar_images: {CharacterName: Image}
local COLOR_BLOCK_SIZE <const> = 19
local AVATAR_WIDTH <const> = 18
local SCORE_WIDTH <const> = 17
local X_START <const> = 75
local Y_START <const> = 3
local Y_SCORE_ADJUST <const> = 5
local AVATAR_SPACE_PADDING <const> = 10
local TOTAL_WIDTH <const> = screen.WIDTH - X_START - AVATAR_SPACE_PADDING

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
    team: Team
    score: integer
    avatars: {CharacterSelection}
end

function TeamScore.new(team: Team, avatars: {CharacterSelection}): TeamScore
    local self: TeamScore = setmetatable({}, {__index = TeamScore})
    self.team = team
    self.score = 0
    self.avatars = avatars
    return self
end

function TeamScore:get_color(): Color
    return self.team.color
end

local record TeamsScoreBoard is ScoreBoard
    teams: {TeamScore}
end

local score_board = {
    ScoreBoard = ScoreBoard,
    SinglesScoreBoard = SinglesScoreBoard,
    TeamsScoreBoard = TeamsScoreBoard,
}

function PlayerScore.new(id: integer, avatar: CharacterName): PlayerScore
    local self: PlayerScore = setmetatable({}, {__index = PlayerScore})
    self.id = id
    self.score = 0
    self.avatar = avatar
    return self
end

local function get_avatar_position(avatar_num: number, num_avatars: number): Point
    local space_for_avatar = AVATAR_WIDTH + SCORE_WIDTH

    local padding = (TOTAL_WIDTH - space_for_avatar * num_avatars) / (num_avatars + 1)
    local x_pos = X_START + padding * avatar_num + space_for_avatar * (avatar_num - 1)
    return points.new(x_pos, Y_START)
end

function SinglesScoreBoard:draw()
    local score_adjust = vectors.new(AVATAR_WIDTH, Y_SCORE_ADJUST)

    for nbr, player in ipairs(self.players) do
        local avatar_pos = get_avatar_position(nbr, #self.players)
        local score_pos = avatar_pos:move(score_adjust)
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
    local self: SinglesScoreBoard = setmetatable({}, {__index = SinglesScoreBoard})
    self.players = {}
    return self
end

local function get_team_width(team: TeamScore): integer
    return SCORE_WIDTH + AVATAR_WIDTH * #team.avatars
end

local function get_team_background_area(x_pos: number, team: TeamScore): Rectangle
    local color_background_y = Y_START - 2 -- Need to cover more space
    return rectangles.new(
        x_pos, color_background_y, get_team_width(team), COLOR_BLOCK_SIZE
    )
end

local function draw_team_boarder(area: Rectangle)
    local boarder_color: Color = {48, 80, 64}
    lutro.graphics.setColor(table.unpack(boarder_color))
    lutro.graphics.rectangle("line", area.x, area.y, area.width, area.height)
end

function TeamsScoreBoard:get_total_width_used(): integer
    local total_width: integer = 0
    for _, team in ipairs(self.teams) do
        total_width = total_width + get_team_width(team)
    end
    return total_width
end

function TeamsScoreBoard:draw()
    local x = X_START + (TOTAL_WIDTH - self:get_total_width_used()) / 2

    for _, team in ipairs(self.teams) do
        local team_background = get_team_background_area(x, team)
        teams.draw_square(team.team, team_background)
        draw_team_boarder(team_background)

        for _, avatar in ipairs(team.avatars) do
            lutro.graphics.draw(avatar_images[avatar.sprite], x, Y_START)
            x = x + AVATAR_WIDTH
        end

        local score_pos = points.new(x + 4, Y_START + Y_SCORE_ADJUST)
        score_font:draw(tostring(team.score), score_pos)
        x = x + SCORE_WIDTH
    end
end

function TeamsScoreBoard:add_point(team_id: integer)
    for _, team in ipairs(self.teams) do
        if team.team.id == team_id then
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

function TeamsScoreBoard:remove_player(player_id: integer)
    for _, team in ipairs(self.teams) do
        for i, avatar in ipairs(team.avatars) do
            if avatar.player_id == player_id then
                table.remove(team.avatars, i)
                return
            end
        end
    end
end

function TeamsScoreBoard:update_avatars(selections: {TeamSelection})
    self.teams = {}
    for _, selection_group in ipairs(teams.grouped_selections(selections)) do
        table.insert(
            self.teams, TeamScore.new(selection_group.team, selection_group.selections)
        )
    end
end

function score_board.new_for_teams(): TeamsScoreBoard
    local self: TeamsScoreBoard = setmetatable({}, {__index = TeamsScoreBoard})
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
