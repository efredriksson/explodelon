local animations = require("engine.animations")
local audio = require("engine.audio")
local battle = require("game.battle")
local characters = require("characters")
local fonts = require("fonts")
local grid = require("level_layout.grid")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local hitboxes = require("engine.hitboxes")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local scenes = require("engine.scenes")
local score_board = require("game.score_board")
local screen = require("screen")
local vectors = require("engine.geometry.vectors")

local type Animation = animations.Animation
local type Battle = battle.Battle
local type CharacterName = characters.CharacterName
local type CharacterSelection = characters.CharacterSelection
local type Color = images.Color
local type Direction = vectors.Direction
local type MenuFont = fonts.MenuFont
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type Scene = scenes.Scene
local type TeamsScoreBoard = score_board.TeamsScoreBoard

local WALK_SPEED = 45
local PLAYER_AREA = rectangles.new(24, 32, 272, 176)
local COUNTDOWN_DURATION = 3.0

local background: Image
local font: MenuFont
local walk_animations: {CharacterName: {Direction: Animation}} = {}
local idle_images: {CharacterName: {Direction: Image}} = {}

local record TeamAssignment
	player_id: integer
	team: integer
	sprite: CharacterName
end

local record TeamZone
	id: integer
	color: Color
	opacity: integer
	bounds: Rectangle
	name: string
end

local function new_zone(id: integer, name: string, color: Color, opacity: integer, area: Rectangle): TeamZone
	local self: TeamZone = setmetatable({}, { __index = TeamZone })
	self.id = id
	self.name = name
	self.color = color
	self.opacity = opacity
	self.bounds = area
	return self
end

local ZONES: {TeamZone} = {
	new_zone(1, "red",    {220, 50, 50}, 80,  rectangles.new( 24,  32, 112, 64)),
	new_zone(2, "blue",   {50, 80, 220}, 80,  rectangles.new(184,  32, 112, 64)),
	new_zone(3, "green",  {50, 180, 50}, 80,  rectangles.new( 24, 144, 112, 64)),
	new_zone(4, "yellow", {220, 200, 50}, 80, rectangles.new(184, 144, 112, 64)),
}

local record TeamPlayer
	player_id: integer
	sprite: CharacterName
	position: Point
	direction: Direction
	walking: boolean
end

local function new_team_player(player_id: integer, sprite: CharacterName, position: Point): TeamPlayer
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

function TeamPlayer:update(dt: number)
	self.walking = false -- Assume no direction
	for _, direction in ipairs(self:get_moves_from_input()) do
		self.walking = true -- Input to walk some direction => is walking

		-- Move player
		local move = vectors.from_direction(direction):scale(WALK_SPEED * dt)
		self.position = self.position:move(move)
		self.direction = direction

		-- Can't move outside of play area:
		self.position = PLAYER_AREA:clamp(self:movementbox()):top_left()
	end
end

function TeamPlayer:get_team_zone(): integer
	for _, zone in ipairs(ZONES) do
		if zone.bounds:contains(self:movementbox()) then
			return zone.id
		end
	end

	return 0
end

-- Sprite draw position (same formula as player_animations.tl:95-99)
local function sprite_draw_pos(anim_width: number, anim_height: number, pos: Point): (number, number)
	return pos.x + (grid.TILE_SIZE - anim_width) / 2,
	       pos.y - anim_height + grid.TILE_SIZE + 1
end

-- The scene

local record TeamSelection is Scene
	team_players: {integer: TeamPlayer}
	score_board: TeamsScoreBoard
	countdown_time: number
	game: Battle
	music: Source
	going_back_to_game: boolean
end

function TeamSelection:load()
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
				selection.player_id, selection.sprite, START_POSITIONS[i]
			)
			self.team_players[selection.player_id] = new_player
		end
	end
end

function TeamSelection:all_ready(): boolean
	for _, player in pairs(self.team_players) do
		if player:get_team_zone() == 0 then
			return false
		end
	end

	return true
end

function TeamSelection:update(dt: number)
	for _, player in pairs(self.team_players) do
		player:update(dt)

		if player.walking then
			walk_animations[player.sprite][player.direction]:update(dt)
		end
	end

	if self:all_ready() then
		self.countdown_time = math.max(self.countdown_time - dt, 0)
	else
		self.countdown_time = COUNTDOWN_DURATION
	end

	-- Transition
	if self.countdown_time == 0 then
		local stored_assignments: {integer: {CharacterSelection}} = {}
		stored_assignments = {}
		for _, player in pairs(self.team_players) do
			stored_assignments[player:get_team_zone()] = {}
		end
		for _, player in pairs(self.team_players) do
			table.insert(
				stored_assignments[player:get_team_zone()],
				CharacterSelection.new(player.player_id, player.sprite)
			)
		end

		self.music:stop()
		self.score_board:update_avatars(stored_assignments)

		if self.going_back_to_game then
			-- The game might have paused audio, make sure to unpause:
			audio.unpause()
		end
		scenes.set(self.game, self.going_back_to_game)
		self.going_back_to_game = true
	end
end

function TeamSelection:draw()
	lutro.graphics.draw(background, 0, 0)

	for _, zone in ipairs(ZONES) do
		local r, g, b = table.unpack(zone.color)
		lutro.graphics.setColor(r, g, b, zone.opacity)
		lutro.graphics.rectangle("fill", zone.bounds.x, zone.bounds.y, zone.bounds.width, zone.bounds.height)

		lutro.graphics.setColor(255, 255, 255)
		local label_y = zone.bounds.y + zone.bounds.height / 2 - 4
		local label_pos = points.new(zone.bounds.x, label_y)
		font:print_centered(zone.name, zone.bounds.width as integer, label_pos)
	end

	local sorted: {TeamPlayer} = {}
	for _, p in pairs(self.team_players) do
		table.insert(sorted, p)
	end
	table.sort(sorted, function(a: TeamPlayer, b: TeamPlayer): boolean
		return a.position.y < b.position.y
	end)

	for _, player in ipairs(sorted) do
		if player.walking then
			local anim = walk_animations[player.sprite][player.direction]
			local draw_x, draw_y = sprite_draw_pos(anim.width, anim.height, player.position)
			anim:draw(draw_x, draw_y)
		else
			local img = idle_images[player.sprite][player.direction]
			local img_w = img:getWidth()
			local img_h = img:getHeight()
			local draw_x, draw_y = sprite_draw_pos(img_w, img_h, player.position)
			lutro.graphics.draw(img, draw_x, draw_y)
		end
	end

	if self:all_ready() then
		local seconds_left = math.ceil(self.countdown_time)
		local text = "start in " .. seconds_left
		local text_pos = points.new(0, 105)
		font:print_centered(text, screen.WIDTH, text_pos)
	end
end

local team_selection = {TeamAssignment = TeamAssignment, TeamSelection = TeamSelection}

function team_selection.load_assets()
	local all_directions: {Direction} = {"up", "down", "left", "right"}
	
	background = lutro.graphics.newImage("assets/grass.png")
	font = fonts.new_menu_white_outlined()

	for _, sprite_name in ipairs(characters.get_names()) do
		walk_animations[sprite_name] = {}
		idle_images[sprite_name] = {}
		for _, dir in ipairs(all_directions) do
			local walk_path = "assets/" .. sprite_name .. "/foot/walk_" .. dir .. ".png"
			walk_animations[sprite_name][dir] = animations.new(
				lutro.graphics.newImage(walk_path), 18, 1/6
			)

			local idle_path = "assets/" .. sprite_name .. "/foot/idle_" .. dir .. ".png"
			idle_images[sprite_name][dir] = lutro.graphics.newImage(idle_path)
		end
	end
end

function team_selection.new(game: Battle, music: Source, teams_score_board: TeamsScoreBoard): TeamSelection
	local self: TeamSelection = setmetatable({}, { __index = TeamSelection })
	self.team_players = {}
	self.score_board = teams_score_board
	self.countdown_time = 0
	self.music = music
	self.game = game
	self.going_back_to_game = false
	return self
end

return team_selection
