require("character_sprites")
require("scenes")
local bombs = require("bombs")
local const = require("const")
local eggs = require("eggs")
local game_countdown = require("game_countdown")
local game_timer = require("game_timer")
local hitboxes = require("hitboxes")
local items = require("items")
local itertools = require("itertools")
local joysticks = require("joysticks")
local level_map = require("level_map")
local mad_bombers = require("mad_bombers")
local movement = require("movement")
local player_animations = require("player_animations")
local players = require("players")
local pressure_blocks = require("pressure_block")
local score_board = require("score_board")
local settings = require("settings")
local soft_blocks = require("soft_blocks")


local JOYPAD = joysticks.buttons()

local record Game is Scene
	score_board: ScoreBoard
	character_sprites: {CharacterSprite}

	bombs: Bombs
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
	game_countdown: GameCountdown
	pressure_blocks: PressureBlocks
end

function Game:load()
	self.players = {}
	local start_positions = level_map.get_player_start_positions(#self.character_sprites)
	for i, sprite in ipairs(self.character_sprites) do
		table.insert(self.players, players.new(i, sprite, start_positions[i]))
	end

	self.bombs = bombs.new()
	self.soft_blocks = soft_blocks.new(level_map.get_soft_blocks(self.players))
	self.mad_bombers = mad_bombers.new(self.bombs)
	self.eggs = eggs.new()
	self.items = items.new()
	self.game_timer = game_timer.new()
	self.player_animations = player_animations.new(self.players)
	self.time_to_wait_to_end_game = 2.0
	self.time_of_1_alive_player = 0.0
	self.game_countdown = game_countdown.new()
	self.pressure_blocks = pressure_blocks.new()
end

function Game.new(character_sprites: {CharacterSprite}): Game
   	local self: Game = setmetatable({}, { __index = Game })
	self.character_sprites = character_sprites
	self.score_board = score_board.new(character_sprites)
	self.background = lutro.graphics.newImage("assets/footboll-map.png")
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
		local position = destroyer:get_position()
		
		for _, entity_list in ipairs({...}) do
			for j, entity in ipairs(entity_list) do
				if position:in_radius_of(entity:get_position(), const.BLOCK_SIZE / 2) then
					table.remove(entity_list, j)
				end
			end
		end
	end
end

function Game:handle_bomb_drop_input(player: Player)
	if joysticks.is_pressed(player.id, JOYPAD.R) then
		self.bombs:place_bomb(player)
	end
end

local is_alive = function(player: Player): boolean
	return player:is_alive()
end

local is_dead = function(player: Player): boolean
	return not player:is_alive()
end

function Game:update(dt: number)
	self.game_countdown:update(dt)
	if not self.game_countdown:finished() then
		return
	end

	self.game_timer:update(dt)
	self.pressure_blocks.sudden_death = self.game_timer:sudden_death()

	local hitting_ground = self.pressure_blocks:update(dt)
	local alive_players = itertools.filter(self.players, is_alive)
	local blocks_bombs: {BlocksBombs} = itertools.combine(
		self.soft_blocks.on_ground,
		level_map.get_hard_blocks(),
		itertools.filter(self.players, is_alive),
		self.bombs.on_ground,
		self.pressure_blocks.on_ground
	)
	local blockers: {ExplosionBlocking} = itertools.combine(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground,
		level_map.get_hard_blocks()
	)
	local explodables: {Explodable} = itertools.combine(
		self.players,
		self.soft_blocks.on_ground,
		self.eggs.on_ground,
		self.items.on_ground
	)

	self.bombs:update(dt, blockers, explodables, blocks_bombs)
	for _, bomb in ipairs(self.bombs:to_hand_back()) do
		local player = self.players[bomb.owner_id]
		player.bombs = player.bombs + 1
	end

	for _, player in ipairs(alive_players) do
		player:update(dt)
		if player:accepts_input() then
			self:handle_bomb_drop_input(player)
			local blocking_blocks = hitboxes.get_for_blocks(
				itertools.combine(self.soft_blocks.on_ground, self.pressure_blocks.on_ground)
			)
			movement.set_position_and_dir_from_input(
				player, dt, blocking_blocks, self.bombs, blocks_bombs
			)
		end

		self.items:possible_pickup_by(player)

		local hatching_dino = self.eggs:possible_hatcher_at(player.position, player.direction)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			self.player_animations.dinos:add_for(hatching_dino)
		end

		local player_hitbox = hitboxes.new(player.position)
		for _, block in ipairs(hitting_ground) do
			local block_hitbox = hitboxes.new(block.position)
			if player_hitbox:center_distance(block_hitbox) < const.BLOCK_SIZE / 2 then
				player:kill()
			end
		end
	end
	for _, player in ipairs(itertools.filter(self.players, is_dead)) do
		if settings.mad_bombers then
			self.mad_bombers:ensure_exist_for(player.id, player.sprite)
		end
	end

	if self.game_timer:sudden_death() then
		-- Remove all mad bombers when sudden death
		self.mad_bombers.by_player = {}
	end
	
	self.mad_bombers:update(dt)
	self.items:update(dt)
	self.eggs:update(dt)

	local dead_players = itertools.filter(self.players, is_dead)
	self.items:drop_items_of(dead_players, self:get_available_spots())

	local removes_items: {Entity} = itertools.combine(hitting_ground, self.bombs.on_ground)
	self:clear_entities(removes_items, self.eggs.on_ground, self.items.on_ground)
	self:clear_entities(hitting_ground, self.bombs.on_ground)
	
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

	if #alive_players <= 1 then
		self.time_of_1_alive_player = self.time_of_1_alive_player + dt
	elseif self.game_timer:out_of_time() then
		self:load() -- Many alive and time out => draw
	end

	if self.time_of_1_alive_player > self.time_to_wait_to_end_game then
		if #alive_players == 1 then
			self.score_board:add_point(alive_players[1].id)
			self:load()
		else
			self:load()
		end
	end
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
	end

	self.game_timer:draw()
	self.game_countdown:draw()

	for _, block in ipairs(self.pressure_blocks:falling()) do
		-- falling blocks are rendered last on top of everything,
		-- but their shadows have to be behind anything
		block:draw_shadow()
	end
	for _, block in ipairs(self.pressure_blocks.on_ground) do
		block:draw()
	end

	self.score_board:draw()

	local entities_to_draw: {Entity} = itertools.combine(
		self.player_animations:get_all(),
		self.items.on_ground,
		self.pressure_blocks:falling(),
		self.eggs.on_ground,
		self.bombs.in_air
	)

	-- Need to render entities in the front last so they are on top of any other entity
	sort_entities_by_y_cord(entities_to_draw)

	-- Drawing this outside "entities_to_draw" so that bombs are always drawn
	-- underneath players
	self.bombs:draw()

	for _, entity in ipairs(entities_to_draw) do
		entity:draw()
	end

	-- Draw soft blocks exploding last, revealing possible item under
	for _, block in ipairs(self.soft_blocks:exploding()) do
		block:draw()
	end

	for _, cart in ipairs(self.mad_bombers:to_draw()) do
		cart:draw()
	end
end

local game = {}

function game.setup(selected_sprites: {CharacterSprite}): Scene
	Eggs.load_assets()
	Items:load_assets()
	GameTimer.load_assets()
	Bombs.load_assets()
	Explosions.load_assets()
	PressureBlocks.load_assets()
	SoftBlocks.load_assets()
	MadBombers.load_assets()
	GameCountdown.load_assets()
	ScoreBoard.load_assets()

	return Game.new(selected_sprites)
end

return game
