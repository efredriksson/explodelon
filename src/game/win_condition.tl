local characters = require("characters")
local players = require("players")
local score_board = require("game.score_board")

local type CharacterName = characters.CharacterName
local type Player = players.Player
local type ScoreBoard = score_board.ScoreBoard

local interface WinCondition
    reset: function(self)
    update: function(self, dt: number, alive_players: {Player})
    is_standing_count: boolean
    is_draw: boolean -- Does not include draw by timeout
    have_winner: boolean
    winners: {CharacterName}
end

local record SinglesWinCondition is WinCondition
    time_of_1_alive_player: number
    score_board: ScoreBoard
end

local win_condition = {WinCondition = WinCondition}
local time_to_wait_to_end_game<const> = 2.0

function SinglesWinCondition:update(dt: number, players_: {Player})
    local alive_players: {Player} = {}
    for _, player in ipairs(players_) do
        if player:is_alive() then
            table.insert(alive_players, player)
        end
    end

    if #alive_players <= 1 then
        self.time_of_1_alive_player = self.time_of_1_alive_player + dt
        self.is_standing_count = true
    end

    if not self.have_winner and self.time_of_1_alive_player > time_to_wait_to_end_game then
        local winner = alive_players[1]
        self.score_board:add_point(winner.id)
        self.have_winner = true
        table.insert(self.winners, winner.sprite)
    end

    self.is_draw = (#alive_players == 0)
end

function SinglesWinCondition:reset()
    self.time_of_1_alive_player = 0
    self.is_standing_count = false
    self.is_draw = false
    self.have_winner = false
    self.winners = {}
end

function win_condition.new_for_singles(score_board_: ScoreBoard): SinglesWinCondition
    local self: SinglesWinCondition = setmetatable({}, { __index = SinglesWinCondition })
    self.score_board = score_board_
    self:reset()
    return self
end

return win_condition
