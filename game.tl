require("const")
require("geometry")
require("player")
require("animation")
require("scene")
require("game_timer")
require("fonts")
require("items")
require("level_map")
require("movement")
require("pressure_block")
require("eggs")
require("dino_animations")
require("bombs")
require("input")
require("character_sprites")
require("soft_blocks")
require("carts")
require("hitboxes")
require("game_countdown")
require("score_board")
require("player_animations")


local function setup_players(selected_sprites: {CharacterSprite}): {Player}
	local players = {}

	local start_positions = get_player_start_positions(#selected_sprites)
	for i, sprite in ipairs(selected_sprites) do
		table.insert(players, Player.new(i, sprite, start_positions[i]))
	end

	return players
end

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
	self.players = setup_players(self.character_sprites)
	self.bombs = Bombs.new()

	self.soft_blocks = SoftBlocks.new(get_soft_blocks(self.players))
	self.mad_bombers = MadBombers.new(self.bombs)
	self.eggs = Eggs.new()
	self.items = Items.new()
	self.game_timer = GameTimer.new()
	self.player_animations = PlayerAnimations.new(self.players)
	self.time_to_wait_to_end_game = 2.0
	self.time_of_1_alive_player = 0.0
	self.game_countdown = GameCountdown.new()
	self.pressure_blocks = PressureBlocks.new()
end

function Game.new(character_sprites: {CharacterSprite}): Game
   	local self: Game = setmetatable({}, { __index = Game })
	self.character_sprites = character_sprites
	self.score_board = ScoreBoard.new(character_sprites)
	self.background = lutro.graphics.newImage("assets/footboll-map.png")
	self:load()
   	return self
end

function Game:get_available_spots(): {Point}
	-- Return places an item/egg can drop. The spot needs to
	-- be free and not too close to a player
	local available_spots: {Point} = {}
	
	local occupied: {Entity} = combine(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground
	)

	for _, pos in ipairs(NON_HARD_POSITIONS) do
		local invalid_position = false
		for _, player in ipairs(self.players) do
			if player.position:distance_to(pos) < BLOCK_SIZE * 2 then
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

function Game:clear_items_and_eggs(destroys: {Entity})
	-- This is for things that directly removes items and eggs (no animations or such)
	for _, entity in ipairs(destroys) do
		local position = entity:get_position()
		for j, item in ipairs(self.items.on_ground) do
			if position:in_radius_of(item.position, BLOCK_SIZE / 2) then
				table.remove(self.items.on_ground, j)
			end
		end
		for j, egg in ipairs(self.eggs.on_ground) do
			if position:in_radius_of(egg.position, BLOCK_SIZE / 2) then
				table.remove(self.eggs.on_ground, j)
			end
		end
	end
end

function Game:handle_bomb_drop_input(player: Player)
	if joystick_is_pressed(player.id, JOYPAD_R) then
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
	local alive_players = filter(self.players, is_alive)
	local blocks_bombs: {BlocksBombs} = combine(
		self.soft_blocks.on_ground,
		HARD_BLOCKS,
		filter(self.players, is_alive),
		self.bombs.on_ground
	)
	local blockers: {ExplosionBlocking} = combine(
		self.eggs.on_ground,
		self.items.on_ground,
		self.soft_blocks.on_ground,
		self.pressure_blocks.on_ground,
		HARD_BLOCKS
	)
	local explodables: {Explodable} = combine(
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
			local blocking_blocks = get_block_hitboxes(
				combine(self.soft_blocks.on_ground, self.pressure_blocks.on_ground)
			)
			set_position_and_dir_from_input(player, dt, blocking_blocks, self.bombs, blocks_bombs)
		end

		self.items:possible_pickup_by(player)

		local hatching_dino = self.eggs:possible_hatcher_at(player.position, player.direction)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			self.player_animations.dinos:add_for(hatching_dino)
		end

		local player_hitbox = new_hitbox(player.position)
		for _, block in ipairs(hitting_ground) do
			local block_hitbox = new_hitbox(block.position)
			if player_hitbox:center_distance(block_hitbox) < BLOCK_SIZE / 2 then
				player:kill()
			end
		end
	end
	for _, player in ipairs(filter(self.players, is_dead)) do
		self.mad_bombers:ensure_exist_for(player.id, player.sprite)
	end

	if self.game_timer:sudden_death() then
		-- Remove all mad bombers when sudden death
		self.mad_bombers.by_player = {}
	end
	
	self.mad_bombers:update(dt)
	self.items:update(dt)
	self.eggs:update(dt)

	local dead_players = filter(self.players, is_dead)
	self.items:drop_items_of(dead_players, self:get_available_spots())

	local remove_items: {Entity} = combine(hitting_ground, self.bombs.on_ground)
	self:clear_items_and_eggs(remove_items)
	
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

	local entities_to_draw: {Entity} = combine(
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

local function setup(selected_sprites: {CharacterSprite}): Scene
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

return setup
