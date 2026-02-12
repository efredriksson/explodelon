local audio = require("engine.audio")
local background = require("level_graphics.background")
local battle_end_scene = require("game.battle_end_scene")
local bombs = require("bombs.bombs")
local characters = require("characters")
local collision = require("engine.collision")
local dino_animations = require("dino_animations")
local dino_inputs = require("dino_inputs")
local eggs = require("eggs")
local explosions = require("bombs.explosions")
local countdown = require("game.countdown")
local timer = require("game.timer")
local pause_scene = require("game.pause_scene")
local grid = require("level_layout.grid")
local hard_blocks = require("hard_blocks")
local hitboxes = require("engine.hitboxes")
local items = require("items")
local itertools = require("itertools")
local joysticks = require("engine.joysticks")
local level_graphics = require("level_graphics.maps.init")
local lightnings = require("bombs.lightnings")
local lightning_bombs = require("bombs.lightning_bombs")
local mad_bombers = require("mad_bombers")
local map_entities = require("level_layout.map_entities")
local movement = require("movement")
local player_animations = require("player_animations")
local players = require("players")
local points = require("engine.geometry.points")
local pressure_blocks = require("pressure_block")
local scenes = require("engine.scenes")
local score_board = require("game.score_board")
local settings = require("settings")
local soft_blocks = require("soft_blocks")

local type Bomb = bombs.Bomb
local type Bombs = bombs.Bombs
local type Eggs = eggs.Eggs
local type Explodable = require("bombs.explodable")
local type Kinematic = require("kinematic")
local type Entity = require("engine.entity")
local type GameCountdown = countdown.GameCountdown
local type HardBlock = hard_blocks.HardBlock
local type HardBlocks = hard_blocks.HardBlocks
local type Items = items.Items
local type LightningBombs = lightning_bombs.LightningBombs
local type MadBombers = mad_bombers.MadBombers
local type PlayerAnimations = player_animations.PlayerAnimations
local type Player = players.Player
local type PressureBlocks = pressure_blocks.PressureBlocks
local type SoftBlocks = soft_blocks.SoftBlocks
local type Group = collision.Group
local type Lookup = collision.Lookup
local type Scene = scenes.Scene
local type ScoreBoard = score_board.ScoreBoard
local type GameTimer = timer.GameTimer
local type Point = points.Point

local music: Source

local type BattleState = enum
   "starting"
   "ongoing"
   "restarting"
   "finished"
end

local record Battle is Scene
	score_board: ScoreBoard
	player_selection: Scene
	
	hard_blocks: HardBlocks
	hard_blocks_group: Group<HardBlock>
	non_hard_block_positions: {Point}
	bombs: Bombs
	lightning_bombs: LightningBombs
	soft_blocks: SoftBlocks
	mad_bombers: MadBombers
	eggs: Eggs
	items: Items
	timer: GameTimer
	players: {Player}
	player_animations: PlayerAnimations
	time_to_wait_to_end_game: number
	time_of_1_alive_player: number
	state: BattleState
	countdown: GameCountdown
	pressure_blocks: PressureBlocks
	tic_counter: integer
	audio_paused: boolean
end

function Battle:load()
	self.players = {}
	local character_selections = characters.get_selections()
	local start_positions = map_entities.get_player_start_positions(#character_selections)
	for i, character_selection in ipairs(character_selections) do
		table.insert(self.players, players.new(
			character_selection.player_id,
			character_selection.sprite,
			start_positions[i])
		)
	end

	self.bombs = bombs.new()
	self.lightning_bombs = lightning_bombs.new()
	self.soft_blocks = soft_blocks.new(map_entities.get_soft_blocks(self.players))
	self.mad_bombers = mad_bombers.new(self.bombs)
	self.eggs = eggs.new()
	self.items = items.new()
	self.timer = timer.new()
	self.player_animations = player_animations.new(self.players)
	self.time_to_wait_to_end_game = 2.0
	self.time_of_1_alive_player = 0.0
	self.state = "starting"
	self.countdown = countdown.new()
	self.pressure_blocks = pressure_blocks.new()
	self.hard_blocks = hard_blocks.new(map_entities.get_hard_blocks())
	self.hard_blocks_group = collision.new_group(self.hard_blocks.on_ground)
	self.non_hard_block_positions = map_entities.get_non_hard_block_positions()
	self.tic_counter = 0
	self.audio_paused = false
	music:stop()
end

function Battle.new(player_selection: Scene): Battle
   	local self: Battle = setmetatable({}, { __index = Battle })
	self.player_selection = player_selection
	self.score_board = score_board.new(characters.get_selections())
	self:load()
   	return self
end

function Battle:get_available_spots(alive_players: {Player}): {Point}
	-- Return places an item/egg can drop. The spot needs to
	-- be free and not too close to a player
	local available_spots: {Point} = {}
	
	local occupied: {Entity} = itertools.combine(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground
	)

	local function valid_position(pos: Point): boolean
		for _, player in ipairs(alive_players) do
			if player.position:distance_to(pos) < grid.TILE_SIZE * 2 then
				return false
			end
		end

		for _, entity in ipairs(occupied) do
			if entity:get_position():equal(pos) then
				return false
			end
		end
		return true
	end

	for _, pos in ipairs(self.non_hard_block_positions) do
		if valid_position(pos) then
			table.insert(available_spots, pos)
		end
	end

	return available_spots
end

function Battle:clear_entities(lookup: Lookup, destroys: Group<Entity>, ...: {Entity})
	-- This is for things that directly removes an entity (no animations or such)
	for _, entity_list in ipairs({...}) do
		local is_destroyed = lookup:collisions_between(entity_list, destroys)
		for i, entity in ipairs(entity_list) do
			if is_destroyed[entity] then
				if entity.clear then
					entity:clear()
				end
				table.remove(entity_list, i)
			end
		end
	end
end

function Battle:handle_bomb_drop_input(player: Player)
	local placed_bombs: {Entity} = itertools.combine(
		self.bombs.on_ground, self.lightning_bombs.on_ground
	)
	if joysticks.is_pressed(player.id, joysticks.BUTTONS.R) then
		self.bombs:place_bomb(player, placed_bombs)
	end

	if joysticks.is_pressed(player.id, joysticks.BUTTONS.Y) then
		self.lightning_bombs:place_lightning_bomb(player, placed_bombs)
	end
end

function Battle:update_players()
	self.score_board:update_avatars(characters.get_selections())
end

function Battle:get_player(player_id: integer): Player
	for _, player in ipairs(self.players) do
		if player_id == player.id then
			return player
		end
	end

	return nil
end

function Battle:join_with_next_free_sprite(player_id: integer)
	characters.new_selection(player_id)
	self:update_players()
end

function Battle:handle_pause_input(): boolean
	if self.state == "finished" then
		return
	end

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

			if self.state == "starting" then
				-- If someone joins while game is still starting we restart so
				-- they can join and play directly.
				self.state = "restarting"
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

	for player_id=1, joysticks.maxplayers() do
		if joysticks.is_pressed(player_id, joysticks.BUTTONS.START) then
			self.countdown = countdown.new()
			self.audio_paused = true
			audio.pause()
			scenes.set(pause_scene.new(
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

local is_effective_roaring = function(player: Player): boolean
	return player:is_effective_roaring()
end

function Battle:check_if_finished(dt: number, alive_players: {Player})
	if self.state == "finished" then
		return
	end

	if #alive_players <= 1 then
		self.time_of_1_alive_player = self.time_of_1_alive_player + dt
	elseif self.timer:out_of_time() then
		self.state = "finished"
		-- Many alive and time out => draw
		music:stop()
		scenes.set(battle_end_scene.new_for_timeout(self))
	end

	if self.time_of_1_alive_player > self.time_to_wait_to_end_game then
		self.state = "finished"
		if #alive_players == 1 then
			local winner = alive_players[1]
			local score = self.score_board:add_point(winner.id)
			music:stop()
			scenes.set(battle_end_scene.new_for_winner(self, winner.sprite, score))
		else
			music:stop()
			scenes.set(battle_end_scene.new_for_draw(self))
		end
	end
end

function Battle:update(dt: number)
	if self.state == "restarting" then
		self:load()
	end

	local is_paused = self:handle_pause_input()
	if is_paused then
		return
	end

	self.countdown:update(dt)
	if not self.countdown:finished() then
		return
	end
	if self.state == "starting" then
		self.state = "ongoing"
		music:play()
	end
	if self.audio_paused then
		self.audio_paused = false
		audio.unpause()
	end

	self.timer:update(dt)
	self.pressure_blocks.sudden_death = self.timer:sudden_death()

	self.pressure_blocks:update(dt)
	local alive_players = itertools.filter(self.players, is_alive)
	local dead_players = itertools.filter(self.players, is_dead)
	local blocks_bombs: Group<Kinematic> = collision.new_group(
		self.soft_blocks.on_ground,
		self.hard_blocks.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground
	)
	local bombs_bounce_on: Group<Kinematic> = collision.new_group(
		self.soft_blocks.on_ground,
		self.hard_blocks.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground,
		self.bombs.on_ground,
		alive_players
	)
	local blocks_jump: Group<Kinematic> = collision.new_group(
		self.soft_blocks.on_ground,
		self.hard_blocks.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground,
		self.bombs.on_ground
	)
	local blockers: Group<Explodable> = collision.new_group(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground,
		self.hard_blocks.on_ground
	)
	local explodables: Group<Explodable> = collision.new_group(
		self.players,
		self.bombs.on_ground,
		self.eggs.on_ground,
		self.items.on_ground
	)
	local lightning_blockers: Group<Explodable> = collision.new_group(
		self.pressure_blocks.on_ground,
		self.hard_blocks.on_ground
	)
	local pressure_blocks_group: Group<Entity> = collision.new_group(self.pressure_blocks.on_ground)
	local bombs_group: Group<Bomb> = collision.new_group(self.bombs.on_ground)
	local bomb_entities_group: Group<Entity> = collision.new_group(self.bombs.on_ground)
	local blocking_blocks_group: Group<Kinematic> = collision.new_group(self.soft_blocks.on_ground, self.pressure_blocks.on_ground)
	local lookup = collision.new_lookup(
		self.soft_blocks.on_ground,
		self.hard_blocks.on_ground,
		self.eggs.on_ground,
		self.items.on_ground,
		alive_players,
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground
	)
	local alive_players_group = collision.new_group(alive_players)
	self.bombs:update(dt, blockers, explodables, blocks_bombs, alive_players_group, bombs_group, bombs_bounce_on, lookup)
	self.lightning_bombs:update(dt, lightning_blockers, alive_players_group, lookup)

	for _, player in ipairs(alive_players) do
		player:update(dt)
		if player:accepts_input() then
			self:handle_bomb_drop_input(player)
			local area_close_to_player = player:movementbox():expand(grid.TILE_SIZE / 2)
			local blocking_blocks = lookup:in_box_and_group(area_close_to_player, blocking_blocks_group)
			local close_hard_blocks = lookup:in_box_and_group(area_close_to_player, self.hard_blocks_group)
			movement.set_position_and_dir_from_input(
				player, dt, blocking_blocks, close_hard_blocks, self.lightning_bombs, blocks_bombs, alive_players_group, bombs_group, lookup
			)
			dino_inputs.handle(dt, player, self.bombs, blocks_jump, bombs_group, lookup)
		end

		self.items:possible_pickup_by(player)

		local hatching_dino = self.eggs:possible_hatcher(player)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			self.player_animations.dinos:add_for(hatching_dino)
		end
	end

	for _, player in ipairs(itertools.filter(self.players, is_effective_roaring)) do
		local hit_players = lookup:in_box_and_group(player:get_roar_hitbox(), alive_players_group)
		for _, hit_player in ipairs(hit_players) do
			if hit_player.action ~= "stunned" then
				-- Roar only stun someone not already stunned
				-- so not possible to perpetually stun in area
				hit_player:stun_for(1.5)
			end
		end
	end

	local hit_players = lookup:collisions_between(alive_players, pressure_blocks_group)
	for player, _ in pairs(hit_players) do
		player:kill()
	end
	for _, player in ipairs(dead_players) do
		if settings.game_rules.players.mad_bombers then
			self.mad_bombers:ensure_exist_for(player.id, player.sprite)
		end
		if player.is_removed then
			self.mad_bombers.by_player[player.id] = nil
		end
	end

	if settings.clear_mad_bombers(self.timer:sudden_death()) then
		-- Remove all mad bombers
		self.mad_bombers.by_player = {}
	end
	
	self.mad_bombers:update(dt)
	self.items:update(dt)
	self.eggs:update(dt)

	self.tic_counter = self.tic_counter + 1
	if self.tic_counter % 120 == 0 then
		-- Only consider generating these every 120 tic (2 seconds)
		-- This also helps with performance!
		local available_spots = self:get_available_spots(alive_players)
		self.items:possible_drop(available_spots)	
		self.items:drop_items_of(dead_players, available_spots)
	end

	self:clear_entities(
		lookup,
		pressure_blocks_group,
		self.eggs.on_ground,
		self.items.on_ground,
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.soft_blocks.on_ground,
		self.hard_blocks.on_ground
	)
	self:clear_entities(
		lookup,
		bomb_entities_group,
		self.eggs.on_ground,
		self.items.on_ground
	)
	self.player_animations:update(dt)
	self.soft_blocks:update(dt)
	for _, soft_block in ipairs(self.soft_blocks.on_ground) do
		if not soft_block.is_exploding then
			-- Do nothing
		elseif soft_block.item then
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
		if e1.z_index ~= e2.z_index then
			return e1.z_index < e2.z_index 
		end

		return e1:get_position().y < e2:get_position().y
	end
	table.sort(players_to_sort, compare_entity_y_pos)
end

function Battle:draw()
	background.draw()
	self.timer:draw()
	self.countdown:draw()

	for _, block in ipairs(self.pressure_blocks:falling()) do
		-- falling blocks are rendered last on top of everything,
		-- but their shadows have to be behind anything
		block:draw_shadow()
	end

	-- When jumping in place, draw jump shadows under all entities
	self.player_animations:draw_vertical_jump_shadows()
	-- Bomb on ground shadows should also be under all entities
	self.bombs:draw_on_ground_shadows()

	self.score_board:draw()
	self.bombs.explosions:draw()
	self.lightning_bombs.lightnings:draw()

	local entities_to_draw: {Entity} = itertools.combine(
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground,
		self.player_animations:get_all(),
		self.items.on_ground,
		self.pressure_blocks:falling(),
		self.hard_blocks.on_ground,
		self.soft_blocks.on_ground,
		self.eggs.on_ground,
		self.bombs.in_air,
		self.mad_bombers:to_draw()
	)

	-- Need to render entities in the front last so they are on top of any other entity
	sort_entities_by_y_cord(entities_to_draw)

	for _, entity in ipairs(entities_to_draw) do
		entity:draw()
		hitboxes.draw(entity:hitbox())
	end

	-- Bomb thrown in air, draw throw shadows over all entities
	self.bombs:draw_in_air_shadows()
	-- When jumping some distance, draw jump shadows over all entities
	self.player_animations:draw_lateral_jump_shadows()
	-- Put roar text above everything else (with up exception)
	self.player_animations:draw_roar_texts_not_up()

	local mobility_related: {Kinematic} = itertools.combine(
		self.bombs.on_ground,
		self.lightning_bombs.on_ground,
		self.pressure_blocks.on_ground,
		itertools.filter(self.players, is_alive),
		self.hard_blocks.on_ground,
		self.soft_blocks.on_ground
	)
	for _, entity in ipairs(mobility_related) do
		hitboxes.draw_movement(entity:movementbox())
	end
	for _, player in ipairs(itertools.filter(self.players, is_effective_roaring)) do
		hitboxes.draw(player:get_roar_hitbox())
	end

	self.timer:draw_hurry_text()
end

local battle = {Battle = Battle}

function battle.load_assets()
	eggs.load_assets()
	items.load_assets()
	timer.load_assets()
	bombs.load_assets()
	explosions.load_assets()
	lightnings.load_assets()
	lightning_bombs.load_assets()
	pressure_blocks.load_assets()
	level_graphics.load_assets()
	mad_bombers.load_assets()
	countdown.load_assets()
	score_board.load_assets()
	pause_scene.load_assets()
	battle_end_scene.load_assets()
	dino_animations.load_assets()
	players.load_assets()
	player_animations.load_assets()

	music = audio.new_source("assets/music/battle.ogg", "static")
	music:setLooping(true)
	music:setVolume(0.75)
end

function battle.new(player_selection: Scene): Battle
	return Battle.new(player_selection)
end

return battle
