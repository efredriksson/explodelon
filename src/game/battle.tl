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
local maps = require("level_layout.maps.init")
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
local tracing = require("engine.tracing")
local win_condition = require("game.win_condition")

local type Bomb = bombs.Bomb
local type Bombs = bombs.Bombs
local type Eggs = eggs.Eggs
local type Explodable = require("bombs.explodable")
local type Kinematic = require("kinematic")
local type Entity = require("engine.entity")
local type GameCountdown = countdown.GameCountdown
local type HardBlocks = hard_blocks.HardBlocks
local type Items = items.Items
local type LightningBombs = lightning_bombs.LightningBombs
local type MadBombers = mad_bombers.MadBombers
local type PlayerAnimations = player_animations.PlayerAnimations
local type Player = players.Player
local type PressureBlocks = pressure_blocks.PressureBlocks
local type SoftBlocks = soft_blocks.SoftBlocks
local type SoftBlock = soft_blocks.SoftBlock
local type CombinedGroup = collision.CombinedGroup
local type Group = collision.Group
local type Lookup = collision.Lookup
local type ReadableGroup = collision.ReadableGroup
local type Scene = scenes.Scene
local type ScoreBoard = score_board.ScoreBoard
local type GameTimer = timer.GameTimer
local type Point = points.Point
local type WinCondition = win_condition.WinCondition

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
	non_hard_block_positions: {Point}
	bombs: Bombs
	lightning_bombs: LightningBombs
	soft_blocks: SoftBlocks
	mad_bombers: MadBombers
	eggs: Eggs
	items: Items
	timer: GameTimer
	team_by_player_id: {integer: integer}
	players: {Player}
	player_animations: PlayerAnimations
	win_condition: WinCondition
	state: BattleState
	countdown: GameCountdown
	pressure_blocks: PressureBlocks
	tic_counter: integer
	audio_paused: boolean
	pressure_blocks_group: Group<Entity>
	bomb_entities_group: Group<Entity>
	alive_players_group: Group<Player>
	bombs_bounce_on: CombinedGroup<Kinematic>
	explodables: CombinedGroup<Explodable>
	blocks_bombs: CombinedGroup<Kinematic>
	blocks_jump: CombinedGroup<Kinematic>
	blockers: CombinedGroup<Explodable>
	lightning_blockers: CombinedGroup<Explodable>
	blocking_blocks_group: CombinedGroup<Kinematic>
end

function Battle:load()
	self.players = {}
	local character_selections = characters.get_selections()
	local start_positions = map_entities.get_player_start_positions(#character_selections)
	for i, character_selection in ipairs(character_selections) do
		local created_player = players.new(
			character_selection.player_id,
			character_selection.sprite,
			start_positions[i]
		)
		created_player.team_id = self.team_by_player_id[created_player.id]
		table.insert(self.players, created_player)
	end

	self.bombs = bombs.new()
	self.lightning_bombs = lightning_bombs.new()
	local block_configs = map_entities.get_block_configs(self.players)
	self.soft_blocks = soft_blocks.new(block_configs.soft)
	self.mad_bombers = mad_bombers.new(self.bombs)
	self.eggs = eggs.new()
	self.items = items.new()
	self.timer = timer.new()
	self.player_animations = player_animations.new(self.players)
	self.win_condition:reset()
	self.state = "starting"
	self.countdown = countdown.new()
	self.pressure_blocks = pressure_blocks.new()
	self.hard_blocks = hard_blocks.new(block_configs.hard)
	self.non_hard_block_positions = block_configs.non_hard
	self.tic_counter = 0
	self.audio_paused = false
	music:stop()
	self.pressure_blocks_group = collision.new_group_from_set(self.pressure_blocks.on_ground.set)
	self.bomb_entities_group = collision.new_group_from_set(self.bombs.on_ground.set)
	self.alive_players_group = collision.new_group(self.players)
	self.bombs_bounce_on = collision.new_combined_group(
		self.soft_blocks.on_ground.set,
		self.hard_blocks.on_ground.set,
		self.lightning_bombs.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.bombs.on_ground.set,
		self.alive_players_group.set
	)
	self.explodables = collision.new_combined_group(
		self.alive_players_group.set,
		self.bombs.on_ground.set,
		self.eggs.on_ground.set,
		self.items.on_ground.set
	)
	self.blocks_bombs = collision.new_combined_group(
		self.soft_blocks.on_ground.set,
		self.hard_blocks.on_ground.set,
		self.lightning_bombs.on_ground.set,
		self.pressure_blocks.on_ground.set
	)
	self.blocks_jump = collision.new_combined_group(
		self.soft_blocks.on_ground.set,
		self.hard_blocks.on_ground.set,
		self.lightning_bombs.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.bombs.on_ground.set
	)
	self.blockers = collision.new_combined_group(
		self.eggs.on_ground.set,
		self.items.on_ground.set,
		self.soft_blocks.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.hard_blocks.on_ground.set
	)
	self.lightning_blockers = collision.new_combined_group(
		self.pressure_blocks.on_ground.set,
		self.hard_blocks.on_ground.set
	)
	self.blocking_blocks_group = collision.new_combined_group(
		self.soft_blocks.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.hard_blocks.on_ground.set
	)
end

function Battle.new(player_selection: Scene, score_board_: ScoreBoard, win_condition_: WinCondition): Battle
   	local self: Battle = setmetatable({}, { __index = Battle })
	self.team_by_player_id = {}
	self.player_selection = player_selection
	self.score_board = score_board_
	self.win_condition = win_condition_
	self:load()
   	return self
end

function Battle:get_available_spots(alive_players: {Player}): {Point}
	-- Return places an item/egg can drop. The spot needs to
	-- be free and not too close to a player
	local available_spots: {Point} = {}
	
	local occupied: {Entity} = itertools.sets_as_list(
		self.eggs.on_ground.set,
		self.items.on_ground.set,
		self.soft_blocks.on_ground.set,
		self.pressure_blocks.on_ground.set
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


function Battle:handle_bomb_drop_input(player: Player)
	local placed_bombs: {Entity} = itertools.sets_as_list(
		self.bombs.on_ground.set, self.lightning_bombs.on_ground.set
	)
	if joysticks.is_pressed(player.id, joysticks.BUTTONS.R) then
		self.bombs:place_bomb(player, placed_bombs)
	end

	if joysticks.is_pressed(player.id, joysticks.BUTTONS.Y) then
		self.lightning_bombs:place_lightning_bomb(player, placed_bombs)
	end
end

function Battle:get_player(player_id: integer): Player
	for _, player in ipairs(self.players) do
		if player_id == player.id then
			return player
		end
	end

	return nil
end

function Battle:handle_pause_input(): boolean
	if self.state == "finished" then
		return
	end

	local function toggle_if_playing(player_id: integer)
		if not characters.exist_selection_for(player_id) then
			settings.number_of_players = settings.number_of_players + 1
			if settings.player_selection == "off" then
				characters.new_selection(player_id)
			else
				characters.queue_selection_for(player_id)
			end
			scenes.set(self.player_selection)

			if self.state == "starting" then
				-- If someone joins while game is still starting we restart so
				-- they can join and play directly.
				self.state = "restarting"
			end
		else
			settings.number_of_players = settings.number_of_players - 1
			characters.remove_selection_for(player_id)
			self.score_board:remove_player(player_id)
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

function Battle:check_if_finished(dt: number)
	if self.state == "finished" then
		return
	end

	self.win_condition:update(dt, self.players)

	if self.timer:out_of_time() and not self.win_condition.is_standing_count then
		self.state = "finished"
		-- Time out and have not entered standing count => draw
		music:stop()
		scenes.set(battle_end_scene.new_for_timeout(self))
	end

	if self.win_condition.have_winner then
		self.state = "finished"
		music:stop()
		scenes.set(battle_end_scene.new_for_winners(
			self, self.win_condition.winners, self.score_board)
		)
	elseif self.win_condition.is_draw then
		self.state = "finished"
		music:stop()
		scenes.set(battle_end_scene.new_for_draw(self))
	end
end

function Battle:_handle_stun_cry(lookup: Lookup, alive_players: ReadableGroup<Player>, player: Player)
	local hit_players = lookup:in_box_and_group(player:get_stun_cry_hitbox(), alive_players)
	for _, hit_player in ipairs(hit_players) do
		if hit_player.action ~= "stunned" then
			-- Stun cry only stun someone not already stunned
			-- so not possible to perpetually stun in area
			hit_player:stun_for(1.5)
		end
	end
end

function Battle:_handle_sonic_blast(lookup: Lookup, bombs_group: ReadableGroup<Bomb>, soft_blocks_group: ReadableGroup<SoftBlock>, player: Player)
	local hit_bombs = lookup:in_box_and_group(player:get_sonic_blast_hitbox(), bombs_group)
	for _, hit_bomb in ipairs(hit_bombs) do
		hit_bomb:blow_up()
	end

	local hit_blocks = lookup:in_box_and_group(player:get_sonic_blast_hitbox(), soft_blocks_group)
	for _, hit_block in ipairs(hit_blocks) do
		hit_block:reveal()
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
	local trace_collision = tracing.start("collision_groups")
	self.alive_players_group:rebuild(alive_players)
	local lookup = collision.new_lookup(
		self.soft_blocks.on_ground.set,
		self.hard_blocks.on_ground.set,
		self.eggs.on_ground.set,
		self.items.on_ground.set,
		self.bombs.on_ground.set,
		self.lightning_bombs.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.alive_players_group.set
	)
	trace_collision:stop()

	local trace_bombs = tracing.start("bombs")
	self.bombs:update(dt, self.blockers, self.explodables, self.blocks_bombs, self.alive_players_group, self.bombs.on_ground, self.bombs_bounce_on, lookup)
	self.lightning_bombs:update(dt, self.lightning_blockers, self.alive_players_group, lookup)
	trace_bombs:stop()

	local trace_players = tracing.start("players")
	for _, player in ipairs(alive_players) do
		local trace_player_update = tracing.start("update")
		player:update(dt)
		trace_player_update:stop()
		local trace_player_movement = tracing.start("movement")
		if player:accepts_input() then
			self:handle_bomb_drop_input(player)
			local area_close_to_player = player:movementbox():expand(grid.TILE_SIZE / 2)
			local close_blocks = lookup:in_box_and_group(area_close_to_player, self.blocking_blocks_group)
			movement.set_position_and_dir_from_input(
				player, dt, close_blocks, self.lightning_bombs, self.blocks_bombs, self.alive_players_group, self.bombs.on_ground, lookup,
				maps.get_layout():has_ice()
			)
			dino_inputs.handle(dt, player, self.bombs, self.blocks_jump, self.bombs.on_ground, lookup)
		end
		trace_player_movement:stop()
		local trace_player_interaction = tracing.start("interaction")

		self.items:possible_pickup_by(player)

		local hatching_dino = self.eggs:possible_hatcher(player)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			self.player_animations.dinos:add_for(hatching_dino)
		end

		if player:is_stun_crying() then
			self:_handle_stun_cry(lookup, self.alive_players_group, player)
		end
		if player:is_sonic_blasting() then
			self:_handle_sonic_blast(lookup, self.bombs.on_ground, self.soft_blocks.on_ground, player)
		end
		trace_player_interaction:stop()
	end
	trace_players:stop()

	local trace_entities = tracing.start("entities")
	local hit_players = lookup:collisions_between(self.alive_players_group, self.pressure_blocks_group)
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

	self.bombs.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
	self.lightning_bombs.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
	self.soft_blocks.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
	self.hard_blocks.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
	self.items.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
	self.items.on_ground:cull_if_hit_by(lookup, self.bomb_entities_group)
	self.eggs.on_ground:cull_if_hit_by(lookup, self.pressure_blocks_group)
	self.eggs.on_ground:cull_if_hit_by(lookup, self.bomb_entities_group)
	self.player_animations:update(dt)
	self.soft_blocks:update(dt)
	for _, soft_block in pairs(self.soft_blocks.on_ground.set) do
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

	self:check_if_finished(dt)
	trace_entities:stop()
end

local function sort_entities_by_y_cord(players_to_sort: {Entity})
	local function compare_entity_y_pos(e1: Entity, e2: Entity): boolean
		if e1.z_index ~= e2.z_index then
			return e1.z_index < e2.z_index
		end
		local pos1 = e1:get_position()
		local pos2 = e2:get_position()
		if pos1.y ~= pos2.y then
			return pos1.y < pos2.y
		end
		if pos1.x ~= pos2.x then
			return pos1.x < pos2.x
		end
		-- tostring gives a stable memory-address-based order within a session,
		-- preventing flickering for entities at identical positions.
		return tostring(e1) < tostring(e2)
	end
	table.sort(players_to_sort, compare_entity_y_pos)
end

function Battle:draw()
	background.draw()
	self.timer:draw()
	self.countdown:draw()

	for _, block in pairs(self.pressure_blocks:falling()) do
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

	local entities_to_draw: {Entity} = itertools.sets_as_list(
		self.bombs.on_ground.set,
		self.lightning_bombs.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.pressure_blocks:falling(),
		self.items.on_ground.set,
		self.hard_blocks.on_ground.set,
		self.soft_blocks.on_ground.set,
		self.eggs.on_ground.set,
		self.bombs.in_air.set,
		self.mad_bombers.by_player,
		self.player_animations:get_all()
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
	-- Put stun cry text above everything else (with up exception)
	self.player_animations:draw_stun_cry_texts_not_up()

	local mobility_related: {Kinematic} = itertools.sets_as_list(
		self.bombs.on_ground.set,
		self.lightning_bombs.on_ground.set,
		self.pressure_blocks.on_ground.set,
		self.hard_blocks.on_ground.set,
		self.soft_blocks.on_ground.set,
		self.alive_players_group.set
	)
	for _, entity in ipairs(mobility_related) do
		hitboxes.draw_movement(entity:movementbox())
	end
	for _, player in pairs(self.alive_players_group.set) do
		if player:is_stun_crying() then
			hitboxes.draw(player:get_stun_cry_hitbox())
		end
		if player:is_sonic_blasting() then
			hitboxes.draw(player:get_sonic_blast_hitbox())
		end
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

function battle.new(player_selection: Scene, score_board_: ScoreBoard, win_condition_: WinCondition): Battle
	return Battle.new(player_selection, score_board_, win_condition_)
end

return battle
