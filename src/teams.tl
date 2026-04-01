local characters = require("characters")
local rectangles = require("engine.geometry.rectangles")
local images = require("engine.images")

local type CharacterName = characters.CharacterName
local type CharacterSelection = characters.CharacterSelection
local type Color = images.Color
local type Rectangle = rectangles.Rectangle

local record Team
    id: integer
    name: string
    color: Color
end

local record TeamSelection
    team: Team
    player_id: integer
    sprite: CharacterName
end

local record TeamSelectionGrouped
    team: Team
    selections: {CharacterSelection}
end

local teams = {Team = Team, TeamSelection = TeamSelection}

function Team.new(id: integer, name: string, color: Color): Team
    local self: Team = setmetatable({}, { __index = Team })
    self.id = id
    self.name = name
    self.color = color
    return self
end

function Team:color_shade(): Color
    local r, g, b = table.unpack(self.color)
    return {r - 25, g - 20, b - 20}
end

function Team:color_darker_shade(): Color
    local r, g, b = table.unpack(self.color)
    return {r - 50, g - 40, b - 40}
end

function TeamSelectionGrouped.new(team: Team): TeamSelectionGrouped
    local self: TeamSelectionGrouped = setmetatable(
        {}, {__index = TeamSelectionGrouped}
    )
    self.team = team
    self.selections = {}
    return self
end

function teams.new_selection(
    team: Team, player_id: integer, sprite: CharacterName
): TeamSelection
    local self: TeamSelection = setmetatable({}, { __index = TeamSelection })
    self.team = team
    self.player_id = player_id
    self.sprite = sprite
    return self
end

function teams.grouped_selections(selections: {TeamSelection}): {TeamSelectionGrouped}
    local character_selections_by_team_id: {integer: {CharacterSelection}} = {}
    local to_return: {TeamSelectionGrouped} = {}

    for _, selection in ipairs(selections) do
        if character_selections_by_team_id[selection.team.id] == nil then
            character_selections_by_team_id[selection.team.id] = {}
            table.insert(to_return, TeamSelectionGrouped.new(selection.team))
        end
        table.insert(
            character_selections_by_team_id[selection.team.id],
            CharacterSelection.new(selection.player_id, selection.sprite)
        )
    end

    for _, group in ipairs(to_return) do
        group.selections = character_selections_by_team_id[group.team.id]
    end

    return to_return
end

local TEAMS: {integer: Team} = {
    [1] = Team.new(1, "red", {255, 105, 97}),
    [2] = Team.new(2, "blue", {186, 225, 255}),
    [3] = Team.new(3, "green", {119, 221, 119}),
    [4] = Team.new(4, "yellow", {253, 253, 150}),
}

function teams.get(id: integer): Team
    assert(TEAMS[id], "Not a valid team ID!")
    return TEAMS[id]
end

function teams.draw_square(team: Team, area: Rectangle, opacity?: integer)
    local r, g, b = table.unpack(team.color)
    lutro.graphics.setColor(r, g, b, opacity)
    lutro.graphics.rectangle("fill", area.x, area.y, area.width, area.height)
end

return teams
