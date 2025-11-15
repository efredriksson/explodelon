local audio = require("audio")
local bombs = require("bombs")
local characters = require("characters")
local const = require("const")
local eggs = require("eggs")
local explosions = require("explosions")
local game_countdown = require("game_countdown")
local game_end = require("game_end")
local game_timer = require("game_timer")
local game_pause = require("game_pause")
local hitboxes = require("hitboxes")
local items = require("items")
local itertools = require("itertools")
local joysticks = require("joysticks")
local level_map = require("level_map")
local lightnings = require("lightnings")
local lightning_bombs = require("lightning_bombs")
local mad_bombers = require("mad_bombers")
local movement = require("movement")
local player_animations = require("player_animations")
local players = require("players")
local pressure_blocks = require("pressure_block")
local scenes = require("scenes")
local score_board = require("score_board")
local settings = require("settings")
local soft_blocks = require("soft_blocks")


local JOYPAD = joysticks.buttons()
local music: Source

global record Game is Scene
	score_board: ScoreBoard
	player_selection: Scene
	hard_blocks: {HardBlock}

	bombs: Bombs
	lightning_bombs: LightningBombs
	background: Image
	soft_blocks: SoftBlocks
	mad_bombers: MadBombers
	eggs: Eggs
	items: Items
	game_timer: GameTimer
	players: {Player}
	player_animations: PlayerAnimations
	time_to_wait_to_end_game: number
	time_of_1_alive_player: number
	have_finished: boolean
	game_countdown: GameCountdown
	pressure_blocks: PressureBlocks
	tic_counter: integer
	audio_paused: boolean
	have_started_music: boolean
end

function Game:load()
	self.players = {}
	local character_selections = characters.get_selections()
	local start_positions = level_map.get_player_start_positions(#character_selections)
	for i, character_selection in ipairs(character_selections) do
		table.insert(self.players, players.new(
			character_selection.player_id,
			character_selection.sprite,
			start_positions[i])
		)
	end

	self.bombs = bombs.new()
	self.lightning_bombs = lightning_bombs.new()
	self.soft_blocks = soft_blocks.new(level_map.get_soft_blocks(self.players))
	self.mad_bombers = mad_bombers.new(self.bombs)
	self.eggs = eggs.new()
	self.items = items.new()
	self.game_timer = game_timer.new()
	self.player_animations = player_animations.new(self.players)
	self.time_to_wait_to_end_game = 2.0
	self.time_of_1_alive_player = 0.0
	self.have_finished = false
	self.game_countdown = game_countdown.new()
	self.pressure_blocks = pressure_blocks.new()
	self.tic_counter = 0
	self.audio_paused = false 
	self.have_started_music = false
	music:stop()
end

function Game.new(player_selection: Scene): Game
   	local self: Game = setmetatable({}, { __index = Game })
	self.player_selection = player_selection
	self.score_board = score_board.new(characters.get_selections())
	self.background = lutro.graphics.newImage("assets/" .. settings.map .. "/background.png")
	self.hard_blocks = level_map.get_hard_blocks()
	self:load()
   	return self
end

function Game:get_available_spots(): {Point}
	-- Return places an item/egg can drop. The spot needs to
	-- be free and not too close to a player
	local available_spots: {Point} = {}
	
	local occupied: {Entity} = itertools.combine(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground
	)

	for _, pos in ipairs(level_map.get_non_hard_block_positions()) do
		local invalid_position = false
		for _, player in ipairs(self.players) do
			if player.position:distance_to(pos) < const.BLOCK_SIZE * 2 then
				invalid_position = true
			end
		end

		for _, entity in ipairs(occupied) do
			if entity:get_position():equal(pos) then
				invalid_position = true
			end
		end

		if not invalid_position then
			table.insert(available_spots, pos)
		end
	end

	return available_spots
end

function Game:clear_entities(destroys: {Entity}, ...: {Entity})
	-- This is for things that directly removes an entity (no animations or such)
	for _, destroyer in ipairs(destroys) do
		for _, entity_list in ipairs({...}) do
			for j, entity in ipairs(entity_list) do
				if destroyer:hitbox():overlap(entity:hitbox()) then
					if entity.clear then
						entity:clear()
					end
					table.remove(entity_list, j)
				end
			end
		end
	end
end

function Game:handle_bomb_drop_input(player: Player)
	local placed_bombs: {Entity} = itertools.combine(
		self.bombs.on_ground, self.lightning_bombs.on_ground
	)
	if joysticks.is_pressed(player.id, JOYPAD.R) then
		self.bombs:place_bomb(player, placed_bombs)
	end

	if joysticks.is_pressed(player.id, JOYPAD.Y) then
		self.lightning_bombs:place_lightning_bomb(player, placed_bombs)
	end
end

function Game:update_players()
	self.score_board:update_avatars(characters.get_selections())
end

function Game:get_player(player_id: integer): Player
	for _, player in ipairs(self.players) do
		if player_id == player.id then
			return player
		end
	end

	return nil
end

function Game:join_with_next_free_sprite(player_id: integer)
	characters.new_selection(player_id)
	self:update_players()
end

function Game:handle_pause_input(): boolean
	local function toggle_if_playing(player_id: integer)
		if not characters.exist_selection_for(player_id) then
			settings.number_of_players = settings.number_of_players + 1
			if self.player_selection then
				characters.queue_selection_for(player_id)
				scenes.set(self.player_selection)
			else
				self:join_with_next_free_sprite(player_id)
				scenes.set(self, true)
			end
		else
			settings.number_of_players = settings.number_of_players - 1
			characters.remove_selection_for(player_id)
			self:update_players()
			local possible_player = self:get_player(player_id)
			if possible_player then
				possible_player:remove()
			end
			scenes.set(self, true)
		end
	end

	for player_id=1, const.MAX_PLAYERS do
		if joysticks.is_pressed(player_id, JOYPAD.START) then
			self.game_countdown = game_countdown.new()
			self.audio_paused = true
			audio.pause()
			scenes.set(game_pause.new(
				self, player_id, characters.exist_selection_for(player_id), toggle_if_playing)
			)
			return true
		end
	end

	return false
end

local is_alive = function(player: Player): boolean
	return player:is_alive()
end

local is_dead = function(player: Player): boolean
	return not player:is_alive()
end

function Game:check_if_finished(dt: number, alive_players: {Player})
	if self.have_finished then
		return
	end

	if #alive_players <= 1 then
		self.time_of_1_alive_player = self.time_of_1_alive_player + dt
	elseif self.game_timer:out_of_time() then
		self.have_finished = true
		-- Many alive and time out => draw
		music:stop()
		scenes.set(game_end.new_for_timeout(self))
	end

	if self.time_of_1_alive_player > self.time_to_wait_to_end_game then
		self.have_finished = true
		if #alive_players == 1 then
			local winner = alive_players[1]
			local score = self.score_board:add_point(winner.id)
			music:stop()
			scenes.set(game_end.new_for_winner(self, winner.sprite, score))
		else
			music:stop()
			scenes.set(game_end.new_for_draw(self))
		end
	end
end

function Game:update(dt: number)
	local is_paused = self:handle_pause_input()
	if is_paused then
		return
	end

	self.game_countdown:update(dt)
	if not self.game_countdown:finished() then
		return
	end
	if not self.have_started_music then
		self.have_started_music = true
		music:play()
	end
	if self.audio_paused then
		self.audio_paused = false
		audio.unpause()
	end

	self.game_timer:update(dt)
	self.pressure_blocks.sudden_death = self.game_timer:sudden_death()

	local hitting_ground = self.pressure_blocks:update(dt)
	local alive_players = itertools.filter(self.players, is_alive)
	local blocks_bombs: {Kinematic} = itertools.combine(
		self.soft_blocks.on_ground,
		self.hard_blocks,
		itertools.filter(self.players, is_alive),
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground
	)
	local blockers: {ExplosionBlocking} = itertools.combine(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground,
		self.hard_blocks
	)
	local explodables: {Explodable} = itertools.combine(
		self.players,
		self.eggs.on_ground,
		self.items.on_ground
	)
	local lightning_blockers: {ExplosionBlocking} = itertools.combine(
		self.pressure_blocks.on_ground,
		self.hard_blocks
	)
	self.bombs:update(dt, blockers, explodables, blocks_bombs)
	self.lightning_bombs:update(dt, lightning_blockers, alive_players)

	for _, player in ipairs(alive_players) do
		player:update(dt)
		if player:accepts_input() then
			self:handle_bomb_drop_input(player)
			local blocking_blocks: {Kinematic} = itertools.combine(
				self.soft_blocks.on_ground, self.pressure_blocks.on_ground
			)
			movement.set_position_and_dir_from_input(
				player, dt, blocking_blocks, self.hard_blocks, self.bombs, self.lightning_bombs, blocks_bombs
			)
		end

		self.items:possible_pickup_by(player)

		local hatching_dino = self.eggs:possible_hatcher(player)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			self.player_animations.dinos:add_for(hatching_dino)
		end

		for _, block in ipairs(hitting_ground) do
			if player:hitbox():overlap(block:hitbox()) then
				player:kill()
			end
		end
	end
	for _, player in ipairs(itertools.filter(self.players, is_dead)) do
		if settings.game_rules.players.mad_bombers and not player.is_removed then
			self.mad_bombers:ensure_exist_for(player.id, player.sprite)
		end
	end

	if settings.clear_mad_bombers(self.game_timer:sudden_death()) then
		-- Remove all mad bombers
		self.mad_bombers.by_player = {}
	end
	
	self.mad_bombers:update(dt)
	self.items:update(dt)
	self.eggs:update(dt)

	self.tic_counter = self.tic_counter + 1
	if self.tic_counter % 120 == 0 then
		-- Only consider generating these every 120 tic (2 seconds)
		self.items:possible_drop(self:get_available_spots())
	end

	local dead_players = itertools.filter(self.players, is_dead)
	self.items:drop_items_of(dead_players, self:get_available_spots())

	local removes_items: {Entity} = itertools.combine(hitting_ground, self.bombs.on_ground)
	self:clear_entities(removes_items, self.eggs.on_ground, self.items.on_ground)
	self:clear_entities(hitting_ground, self.bombs.on_ground, self.lightning_bombs.on_ground, self.soft_blocks.on_ground)
	
	self.player_animations:update(dt)
	self.soft_blocks:update(dt)
	for _, soft_block in ipairs(self.soft_blocks:exploding()) do
		if soft_block.item then
			self.items:drop_at(soft_block.position, soft_block.item)
			soft_block.item = nil
		elseif soft_block.egg then
			self.eggs:spawn_at(soft_block.position)
			soft_block.egg = false
		end
	end

	self:check_if_finished(dt, alive_players)
end

local function sort_entities_by_y_cord(players_to_sort: {Entity})
	local function compare_entity_y_pos(e1: Entity, e2: Entity): boolean
		return e1:get_position().y < e2:get_position().y
	end
	table.sort(players_to_sort, compare_entity_y_pos)
end

function Game:draw()
	lutro.graphics.draw(self.background)
	for _, block in ipairs(self.soft_blocks:not_exploding()) do
		block:draw()
		hitboxes.draw(block:hitbox())
	end

	self.game_timer:draw()
	self.game_countdown:draw()

	for _, block in ipairs(self.pressure_blocks:falling()) do
		-- falling blocks are rendered last on top of everything,
		-- but their shadows have to be behind anything
		block:draw_shadow()
	end

	self.score_board:draw()
	self.bombs.explosions:draw()
	self.lightning_bombs.lightnings:draw()

	local entities_to_draw: {Entity} = itertools.combine(
		self.player_animations:get_all(),
		self.items.on_ground,
		self.pressure_blocks:falling(),
		self.eggs.on_ground,
		self.bombs.in_air
	)

	-- Need to render entities in the front last so they are on top of any other entity
	sort_entities_by_y_cord(entities_to_draw)

	entities_to_draw = itertools.combine(
		-- Drawing bombs first so they are always drawn underneath players	
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground,
		entities_to_draw,
		-- Draw soft blocks exploding last, revealing possible item under
		self.soft_blocks:exploding(),
		self.mad_bombers:to_draw()
	)

	for _, entity in ipairs(entities_to_draw) do
		entity:draw()
		hitboxes.draw(entity:hitbox())
	end

	local mobility_related: {Kinematic} = itertools.combine(
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground,
		itertools.filter(self.players, is_alive),
		self.hard_blocks,
		self.soft_blocks:not_exploding()
	)
	for _, entity in ipairs(mobility_related) do
		hitboxes.draw_movement(entity:movementbox())
	end

	self.game_timer:draw_hurry_text()
end

local game = {}

function game.load_assets()
	Eggs.load_assets()
	Items:load_assets()
	GameTimer.load_assets()
	bombs.load_assets()
	explosions.load_assets()
	lightnings.load_assets()
	lightning_bombs.load_assets()
	PressureBlocks.load_assets()
	SoftBlocks.load_assets()
	MadBombers.load_assets()
	GameCountdown.load_assets()
	ScoreBoard.load_assets()
	game_pause.load_assets()
	game_end.load_assets()

	music = audio.new_source("assets/music/battle.ogg", "static")
	music:setLooping(true)
	music:setVolume(0.75)
end

function game.new(player_selection: Scene): Game
	return Game.new(player_selection)
end

return game
