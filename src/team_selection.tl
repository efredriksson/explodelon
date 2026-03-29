local characters = require("characters")
local animations = require("engine.animations")
local audio = require("engine.audio")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local hitboxes = require("engine.hitboxes")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local battle = require("game.battle")
local score_board = require("game.score_board")
local win_condition = require("game.win_condition")
local grid = require("level_layout.grid")
local screen = require("screen")
local teams = require("teams")

local type Animation = animations.Animation
local type Battle = battle.Battle
local type CharacterName = characters.CharacterName
local type Direction = vectors.Direction
local type MenuFont = fonts.MenuFont
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type Scene = scenes.Scene
local type Team = teams.Team
local type TeamSelection = teams.TeamSelection
local type TeamsScoreBoard = score_board.TeamsScoreBoard
local type TeamsWinCondition = win_condition.TeamsWinCondition

local WALK_SPEED = 45
local COUNTDOWN_DURATION = 3.0

local background: Image
local font: MenuFont
local player_animations: {boolean: {CharacterName: {Direction: Animation}}} = {}

local record TeamAssignment
    player_id: integer
    team: integer
    sprite: CharacterName
end

local record TeamZone
    team: Team
    bounds: Rectangle
end

local function new_zone(team: Team, area: Rectangle): TeamZone
    local self: TeamZone = setmetatable({}, { __index = TeamZone })
    self.team = team
    self.bounds = area
    return self
end

local ZONES: {TeamZone} = {
    new_zone(teams.get(1), rectangles.new(24, 32, 112, 64)),
    new_zone(teams.get(2), rectangles.new(184, 32, 112, 64)),
    new_zone(teams.get(3), rectangles.new(24, 144, 112, 64)),
    new_zone(teams.get(4), rectangles.new(184, 144, 112, 64)),
}

local record TeamPlayer
    player_id: integer
    sprite: CharacterName
    position: Point
    direction: Direction
    walking: boolean
end

local function new_team_player(
    player_id: integer,
    sprite: CharacterName,
    position: Point
): TeamPlayer
    local self: TeamPlayer = setmetatable({}, { __index = TeamPlayer })
    self.player_id = player_id
    self.sprite = sprite
    self.position = position
    self.direction = "down"
    self.walking = false
    return self
end

local START_POSITIONS: {Point} = {
    grid.get_tile_position(8, 4),
    grid.get_tile_position(8, 6),
    grid.get_tile_position(7, 5),
    grid.get_tile_position(9, 5),
    grid.get_tile_position(7, 4),
    grid.get_tile_position(9, 4),
    grid.get_tile_position(7, 6),
    grid.get_tile_position(9, 6),
    grid.get_tile_position(8, 5),
    grid.get_tile_position(8, 3),
}

function TeamPlayer:get_moves_from_input(): {Direction}
    local result: {Direction} = {}

    if lutro.joystick.isDown(self.player_id, joysticks.BUTTONS.DOWN) then
        table.insert(result, "down")
    end
    if lutro.joystick.isDown(self.player_id, joysticks.BUTTONS.UP) then
        table.insert(result, "up")
    end
    if lutro.joystick.isDown(self.player_id, joysticks.BUTTONS.RIGHT) then
        table.insert(result, "right")
    end
    if lutro.joystick.isDown(self.player_id, joysticks.BUTTONS.LEFT) then
        table.insert(result, "left")
    end

    return result
end

function TeamPlayer:movementbox(): Rectangle
    return hitboxes.new_block(self.position)
end

function TeamPlayer:_get_animation(): Animation
    return player_animations[self.walking][self.sprite][self.direction]
end

function TeamPlayer:update(dt: number)
    self.walking = false -- Assume no direction
    for _, direction in ipairs(self:get_moves_from_input()) do
        self.walking = true -- Input to walk some direction => is walking

        -- Move player
        local move = vectors.from_direction(direction):scale(WALK_SPEED * dt)
        self.position = self.position:move(move)
        self.direction = direction

        -- Can't move outside of play area:
        self.position = grid.area():clamp(self:movementbox()):top_left()
    end

    self:_get_animation():update(dt)
end

local function block_to_anim_draw_pos(animation: Animation, pos: Point): Point
    -- y: +1 is because of the sprite, look over when doing animations
    return points.new(
        pos.x + (grid.TILE_SIZE - animation.width) / 2,
        pos.y - animation.height + grid.TILE_SIZE + 1
    )
end

function TeamPlayer:draw()
    local anim = self:_get_animation()
    local draw_pos = block_to_anim_draw_pos(anim, self.position)
    anim:draw(draw_pos.x, draw_pos.y)
end

function TeamPlayer:get_team_zone(): TeamZone
    for _, zone in ipairs(ZONES) do
        if zone.bounds:contains(self:movementbox()) then
            return zone
        end
    end

    return nil
end

local record TeamSelectionScene is Scene
    team_players: {integer: TeamPlayer}
    countdown_time: number
    music: Source
    score_board: TeamsScoreBoard
    win_condition: TeamsWinCondition
    game: Battle
    going_back_to_game: boolean
end

function TeamSelectionScene:load()
    self.countdown_time = COUNTDOWN_DURATION
    local old_states = self.team_players
    self.team_players = {}

    local selections = characters.get_selections()
    for i, selection in ipairs(selections) do
        local old_state = old_states[selection.player_id]
        if old_state and old_state.sprite == selection.sprite then
            self.team_players[selection.player_id] = old_states[selection.player_id]
        else
            local new_player = new_team_player(
                selection.player_id,
                selection.sprite,
                START_POSITIONS[i]
            )
            self.team_players[selection.player_id] = new_player
        end
    end
end

function TeamSelectionScene:all_ready(): boolean
    for _, player in pairs(self.team_players) do
        if player:get_team_zone() == nil then
            return false
        end
    end

    return true
end

function TeamSelectionScene:update(dt: number)
    for _, player in pairs(self.team_players) do
        player:update(dt)
    end

    if self:all_ready() then
        self.countdown_time = math.max(self.countdown_time - dt, 0)
    else
        self.countdown_time = COUNTDOWN_DURATION
    end

    -- Transition
    if self.countdown_time == 0 then
        local selections: {TeamSelection} = {}
        self.game.team_by_player_id = {}
        for _, player in pairs(self.team_players) do
            local team = player:get_team_zone().team
            local selection = teams.new_selection(team, player.player_id, player.sprite)
            table.insert(selections, selection)
            self.game.team_by_player_id[player.player_id] = team.id
        end

        self.music:stop()
        self.score_board:update_avatars(selections)
        self.win_condition:update_team_mapping(selections)

        if self.going_back_to_game then
            -- The game might have paused audio, make sure to unpause:
            audio.unpause()
        end
        scenes.set(self.game, self.going_back_to_game)
        self.going_back_to_game = true
    end
end

function TeamSelectionScene:get_players_to_draw(): {TeamPlayer}
    local players_to_draw: {TeamPlayer} = {}
    for _, p in pairs(self.team_players) do
        table.insert(players_to_draw, p)
    end
    table.sort(players_to_draw, function(a: TeamPlayer, b: TeamPlayer): boolean
        return a.position.y < b.position.y
    end)

    return players_to_draw
end

function TeamSelectionScene:draw()
    lutro.graphics.draw(background, 0, 0)

    for _, zone in ipairs(ZONES) do
        local zone_opacity = 100
        teams.draw_square(zone.team, zone.bounds, zone_opacity)

        local label_y = zone.bounds.y + zone.bounds.height / 2 - 4
        local label_pos = points.new(zone.bounds.x, label_y)
        font:print_centered(zone.team.name, zone.bounds.width, label_pos)
    end

    for _, player in ipairs(self:get_players_to_draw()) do
        player:draw()
    end

    if self:all_ready() then
        local seconds_left = math.ceil(self.countdown_time)
        local text = "start in " .. seconds_left
        local text_pos = points.new(0, 105)
        font:print_centered(text, screen.WIDTH, text_pos)
    end
end

local team_selection = {TeamAssignment = TeamAssignment, TeamSelection = TeamSelection}

local function get_image(
    is_walking: boolean,
    sprite: CharacterName,
    direction: Direction
): Image
    local walk_name = {[true] = "walk", [false] = "idle"}
    local path = "assets/" .. sprite .. "/foot/" .. walk_name[is_walking] .. "_" .. direction .. ".png"
    return lutro.graphics.newImage(path)
end

function team_selection.load_assets()
    local all_directions: {Direction} = {"up", "down", "left", "right"}

    background = lutro.graphics.newImage("assets/grass.png")
    font = fonts.new_menu_white_outlined()

    for _, is_walking in ipairs({true, false}) do
        player_animations[is_walking] = {}
        for _, sprite_name in ipairs(characters.get_names()) do
            player_animations[is_walking][sprite_name] = {}
            for _, direction in ipairs(all_directions) do
                local char_image = get_image(is_walking, sprite_name, direction)
                player_animations[is_walking][sprite_name][direction] = animations.new(
                    char_image,
                    18,
                    1 / 6
                )
            end
        end
    end
end

function team_selection.new(
    player_selection_scene: Scene,
    music: Source
): TeamSelectionScene
    local self: TeamSelectionScene = setmetatable({}, { __index = TeamSelectionScene })
    self.team_players = {}
    self.countdown_time = COUNTDOWN_DURATION
    self.music = music
    self.score_board = score_board.new_for_teams()
    self.win_condition = win_condition.new_for_teams(self.score_board)
    self.game = battle.new(player_selection_scene, self.score_board, self.win_condition)
    self.going_back_to_game = false
    return self
end

return team_selection
