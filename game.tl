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

local bombs: Bombs
local background: Image
local soft_blocks: SoftBlocks
local mad_bombers: MadBombers
local eggs: Eggs
local items: Items
local game_timer: GameTimer
local score_board: ScoreBoard
local character_sprites: {CharacterSprite} = {}
local players: {Player} = {}
local player_animations: PlayerAnimations
local time_to_wait_to_end_game = 2.0
local time_of_1_alive_player = 0.0
local game_countdown: GameCountdown
local pressure_blocks: PressureBlocks

local function setup_players(selected_sprites: {CharacterSprite}): {Player}
	players = {}

	local start_positions = get_player_start_positions(#selected_sprites)
	for i, sprite in ipairs(selected_sprites) do
		table.insert(players, Player.new(i, sprite, start_positions[i]))
	end

	return players
end

local function game_load()
	time_of_1_alive_player = 0
	background = lutro.graphics.newImage("assets/footboll-map.png")
	setup_players(character_sprites)

	player_animations = PlayerAnimations.new(players)
	eggs = Eggs.new()
	items = Items.new()
	game_timer = GameTimer.new()
	bombs = Bombs.new()
	pressure_blocks = PressureBlocks.new()
	soft_blocks = SoftBlocks.new(get_soft_blocks(players))
	mad_bombers = MadBombers.new(bombs)
	game_countdown = GameCountdown.new()
end

local function get_available_spots(): {Point}
	-- Return places an item/egg can drop. The spot needs to
	-- be free and not too close to a player
	local available_spots: {Point} = {}
	
	local occupied: {Entity} = combine(
		eggs.on_ground,
		items.on_ground,
		soft_blocks.on_ground,
		pressure_blocks.on_ground
	)

	for _, pos in ipairs(NON_HARD_POSITIONS) do
		local invalid_position = false
		for _, player in ipairs(players) do
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

local function clear_items_and_eggs(destroys: {Entity})
	-- This is for things that directly removes items and eggs (no animations or such)
	for _, entity in ipairs(destroys) do
		local position = entity:get_position()
		for j, item in ipairs(items.on_ground) do
			if position:in_radius_of(item.position, BLOCK_SIZE / 2) then
				table.remove(items.on_ground, j)
			end
		end
		for j, egg in ipairs(eggs.on_ground) do
			if position:in_radius_of(egg.position, BLOCK_SIZE / 2) then
				table.remove(eggs.on_ground, j)
			end
		end
	end
end

local function handle_bomb_drop_input(player: Player)
	if joystick_is_pressed(player.id, JOYPAD_R) then
		bombs:place_bomb(player)
	end
end

local is_alive = function(player: Player): boolean
	return player:is_alive()
end

local is_dead = function(player: Player): boolean
	return not player:is_alive()
end

local function game_update(dt: number)
	game_countdown:update(dt)
	if not game_countdown:finished() then
		return
	end

	game_timer:update(dt)
	pressure_blocks.sudden_death = game_timer:sudden_death()

	local hitting_ground = pressure_blocks:update(dt)
	local alive_players = filter(players, is_alive)
	local blocks_bombs: {BlocksBombs} = combine(
		soft_blocks.on_ground,
		HARD_BLOCKS,
		filter(players, is_alive),
		bombs.on_ground
	)
	local blockers: {ExplosionBlocking} = combine(
		eggs.on_ground,
		items.on_ground,
		soft_blocks.on_ground,
		pressure_blocks.on_ground,
		HARD_BLOCKS
	)
	local explodables: {Explodable} = combine(
		players, soft_blocks.on_ground, eggs.on_ground, items.on_ground
	)

	bombs:update(dt, blockers, explodables, blocks_bombs)
	for _, bomb in ipairs(bombs:to_hand_back()) do
		local player = players[bomb.owner_id]
		player.bombs = player.bombs + 1
	end

	for _, player in ipairs(alive_players) do
		player:update(dt)
		if player:accepts_input() then
			handle_bomb_drop_input(player)
			local blocking_blocks = get_block_hitboxes(
				combine(soft_blocks.on_ground, pressure_blocks.on_ground)
			)
			set_position_and_dir_from_input(player, dt, blocking_blocks, bombs, blocks_bombs)
		end

		items:possible_pickup_by(player)

		local hatching_dino = eggs:possible_hatcher_at(player.position, player.direction)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			player_animations.dinos:add_for(hatching_dino)
		end

		local player_hitbox = new_hitbox(player.position)
		for _, block in ipairs(hitting_ground) do
			local block_hitbox = new_hitbox(block.position)
			if player_hitbox:center_distance(block_hitbox) < BLOCK_SIZE / 2 then
				player:kill()
			end
		end
	end
	for _, player in ipairs(filter(players, is_dead)) do
		mad_bombers:ensure_exist_for(player.id, player.sprite)
	end

	if game_timer:sudden_death() then
		-- Remove all mad bombers when sudden death
		mad_bombers.by_player = {}
	end
	
	mad_bombers:update(dt)
	items:update(dt)
	eggs:update(dt)

	local dead_players = filter(players, is_dead)
	items:drop_items_of(dead_players, get_available_spots())

	local remove_items: {Entity} = combine(hitting_ground, bombs.on_ground)
	clear_items_and_eggs(remove_items)
	
	if #alive_players <= 1 then
		time_of_1_alive_player = time_of_1_alive_player + dt
	elseif game_timer:out_of_time() then
		game_load() -- Many alive and time out => draw
	end

	if time_of_1_alive_player > time_to_wait_to_end_game then
		if #alive_players == 1 then
			score_board:add_point(alive_players[1].id)
			game_load()
		else
			game_load()
		end
	end
	
	player_animations:update(dt)
	soft_blocks:update(dt)
	for _, soft_block in ipairs(soft_blocks:exploding()) do
		if soft_block.item then
			items:drop_at(soft_block.position, soft_block.item)
			soft_block.item = nil
		elseif soft_block.egg then
			eggs:spawn_at(soft_block.position)
			soft_block.egg = false
		end
	end
end

local function sort_entities_by_y_cord(players_to_sort: {Entity})
	local function compare_entity_y_pos(e1: Entity, e2: Entity): boolean
		return e1:get_position().y < e2:get_position().y
	end
	table.sort(players_to_sort, compare_entity_y_pos)
end

local function game_draw()
	lutro.graphics.draw(background)
	for _, block in ipairs(soft_blocks:not_exploding()) do
		block:draw()
	end

	game_timer:draw()
	game_countdown:draw()

	for _, block in ipairs(pressure_blocks:falling()) do
		-- falling blocks are rendered last on top of everything,
		-- but their shadows have to be behind anything
		block:draw_shadow()
	end
	for _, block in ipairs(pressure_blocks.on_ground) do
		block:draw()
	end

	score_board:draw()

	local entities_to_draw: {Entity} = combine(
		player_animations:get_all(),
		items.on_ground,
		pressure_blocks:falling(),
		eggs.on_ground,
		bombs.in_air
	)

	-- Need to render entities in the front last so they are on top of any other entity
	sort_entities_by_y_cord(entities_to_draw)

	-- Drawing this outside "entities_to_draw" so that bombs are always drawn
	-- underneath players
	bombs:draw()

	for _, entity in ipairs(entities_to_draw) do
		entity:draw()
	end

	-- Draw soft blocks exploding last, revealing possible item under
	for _, block in ipairs(soft_blocks:exploding()) do
		block:draw()
	end

	for _, cart in ipairs(mad_bombers:to_draw()) do
		cart:draw()
	end
end

local function setup(selected_sprites: {CharacterSprite}): Scene
	character_sprites = selected_sprites

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
	score_board = ScoreBoard.new(selected_sprites)

	local module = Scene.new()
	module.load = game_load
	module.update = game_update
	module.draw = game_draw
	return module
end

return setup
