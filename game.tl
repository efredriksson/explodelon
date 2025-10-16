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

local bombs: Bombs
local background: Image
local soft_blocks: SoftBlocks

local function setup_players(selected_sprites: {CharacterSprite}): {Player}
	global players: {Player} = {}
	local start_positions = get_player_start_positions(#selected_sprites)
	for i, sprite in ipairs(selected_sprites) do
		table.insert(players, Player.new(i, sprite, start_positions[i]))
	end

	return players
end

--- Scale 0-1 represent how far from current to max to increase color component 
local function increase_color(color: number, scale: number): number
	return color + scale * (255 - color)
end

local function make_lighter(image: Image)
	local image_data = image:getData()
	local scale = 0.6
	-- Using C index in getPixel API for some reason...
	for i = 0, image:getWidth() - 1 do
		for j = 0, image:getHeight() - 1 do
			local r, g, b, alpha = image_data:getPixel(i, j)
			if alpha ~= 0 then
				r = increase_color(r, scale)
				g = increase_color(g, scale)
				b = increase_color(b, scale)
				image_data:setPixel(i, j, r, g, b, alpha)
			end
		end
	end
end

local function get_animation(asset_file: string, invulnerable: boolean): Animation
	local image = lutro.graphics.newImage(asset_file)
	if invulnerable then
		make_lighter(image)
	end

	return Animation.new(image, 18, 34, 3, 18)
end

local function character_avatar(character_asset: string): Image
	return lutro.graphics.newImage("assets/" .. character_asset .. "/avatar_neutral.png")
end

local function character_animation_for_action(character_asset: string, state: PlayerState, action: Action, invulnerable: boolean): {Direction: Animation}
	if state == "mounted" then
		if action == "jump_on" or action == "jump_off" then
			-- Same sprite for 'jump' when on foot as when mounted
			state = "foot"
		elseif action == "idle" then
			-- Same sprite for 'idle' as 'walk' when mounted
			action = "walk"
		end
	end

	local function action_resolved(): string
		if action == "jump_on" or action == "jump_off" then
			return "jump"
		else
			return action
		end
	end

	local base_path = "assets/" .. character_asset .. "/" .. state .. "/" .. action_resolved()
	return {
		["up"] = get_animation(base_path .. "_up.png", invulnerable),
		["down"] = get_animation(base_path .. "_down.png", invulnerable),
		["right"] = get_animation(base_path .. "_right.png", invulnerable),
		["left"] = get_animation(base_path .. "_left.png", invulnerable),
	}
end

local function character_animations_for_state(character_asset: string, state: PlayerState, invulnerable: boolean): {Action: {Direction: Animation}}
	return {
		["walk"] = character_animation_for_action(character_asset, state, "walk", invulnerable),
		["idle"] = character_animation_for_action(character_asset, state, "idle", invulnerable),
		["jump_on"] = character_animation_for_action(character_asset, state, "jump_on", invulnerable),
		["jump_off"] = character_animation_for_action(character_asset, state, "jump_off", invulnerable),
	}
end

local function character_animation(character_asset: string, invulnerable: boolean): {PlayerState: {Action: {Direction: Animation}}}
	return {
		["foot"] = character_animations_for_state(character_asset, "foot", invulnerable),
		["mounted"] = character_animations_for_state(character_asset, "mounted", invulnerable),
	}
end

local animations: {integer: {PlayerState: {Action: {Direction: Animation}}}} = {}
local animations_invulnerable: {integer: {PlayerState: {Action: {Direction: Animation}}}} = {}
local avatars: {integer: Image} = {}

local function game_load()
	global tic_counter = 0
	background = lutro.graphics.newImage("assets/footboll-map.png")
	local player_positions: {Point} = {}
	for _, player in ipairs(players) do
		animations[player.id] = character_animation(player.sprite, false)
		animations_invulnerable[player.id] = character_animation(player.sprite, true)
		avatars[player.id] = character_avatar(player.sprite)
		table.insert(player_positions, player.position)
	end

	global animated_dinos = AnimatedDinos.new()

	load_egg_assets()
	global eggs = Eggs.new()

	load_item_assets()
	global items = Items.new()

	local time_left = 180
	global game_timer = GameTimer.new(time_left)
	Bombs:load()
	Explosions:load()
	bombs = Bombs.new()
	game_timer:load_assets()
	load_pressure_block_assets()
	global pressure_blocks = PressureBlocks.new(time_left)

	global score_font = get_shaded_number_font()

	soft_blocks = SoftBlocks.new(get_soft_blocks(player_positions))
	soft_blocks:load_assets()
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
			if entity.position:equal(pos) then
				invalid_position = true
			end
		end

		if not invalid_position then
			table.insert(available_spots, pos)
		end
	end

	return available_spots
end

local function transfere_player_data(old_player_datas: {Player})
	for i=1, #players do
		players[i].score = old_player_datas[i].score
	end
end

local function next_game()
	local old_player_datas = players
	local sprites: {CharacterSprite} = {}
	for _, player in ipairs(players) do
		table.insert(sprites, player.sprite)
	end
	setup_players(sprites)
	transfere_player_data(old_player_datas)
	game_load()
end

local function clear_items_and_eggs(hitting_ground: {PressureBlock})
	for _, block in ipairs(hitting_ground) do
		for j, item in ipairs(items.on_ground) do
			if item.position:equal(block.position) then
				table.remove(items.on_ground, j)
			end
		end
		for j, egg in ipairs(eggs.on_ground) do
			if egg.position:equal(block.position) then
				table.remove(eggs.on_ground, j)
			end
		end
	end
end

local function find_closest_non_hard_position(pos: Point): Point
	-- Snap to nearest grid tile
	local x = math.floor((pos.x - PLAYER_AREA.x) / BLOCK_SIZE + 0.5) * BLOCK_SIZE + PLAYER_AREA.x
	local y = math.floor((pos.y - PLAYER_AREA.y) / BLOCK_SIZE + 0.5) * BLOCK_SIZE + PLAYER_AREA.y
	return Point.new(x, y)
end

local function handle_bomb_drop_input(player: Player)
	if joystick_is_pressed(player.id, JOYPAD_R) then
		if (player.bomb_beneath or player.bombs <= 0) then
			return
		end

		local closest_non_hard_position = find_closest_non_hard_position(player.position)
		local bomb = bombs:place_bomb(closest_non_hard_position, player)

		player.bombs = player.bombs - 1
		player.bomb_beneath = bomb
	end
end

local is_alive = function(player: Player): boolean
	return player.is_alive
end

local is_dead = function(player: Player): boolean
	return not player.is_alive
end

local function game_update(dt: number)
	local hitting_ground = pressure_blocks:update(dt)
	local alive_players = filter(players, is_alive)

	for _, player in ipairs(alive_players) do
		player:update(dt)
		if player:accepts_input() then
			handle_bomb_drop_input(player)
			local blocking_blocks = combine(
				soft_blocks:hitboxes(), pressure_blocks:hitboxes()
			)
			set_position_and_dir_from_input(player, dt, blocking_blocks, bombs)
		end

		animations[player.id][player.state][player.action][player.direction]:update(dt)
		animations_invulnerable[player.id][player.state][player.action][player.direction]:update(dt)

		items:possible_pickup_by(player)

		local hatching_dino = eggs:possible_hatcher_at(player.position, player.direction)
		if hatching_dino then
			player:jumps_onto(hatching_dino)
			animated_dinos:add_for(hatching_dino)
		end

		local player_hitbox = new_hit_box(player.position)
		for _, block in ipairs(hitting_ground) do
			local block_hitbox = new_hit_box(block.position)
			if player_hitbox:center_distance(block_hitbox) < BLOCK_SIZE / 2 then
				player:kill()
			end
		end
	end
	
	items:update(dt)
	eggs:update(dt)

	local dead_players = filter(players, is_dead)
	items:drop_items_of(dead_players, get_available_spots())

	clear_items_and_eggs(hitting_ground)
	
	local out_of_time = game_timer:decrement(dt)
	if #alive_players == 1 then
		alive_players[1]:won_game()
		next_game()
	end
	if #alive_players == 0 or out_of_time then
		next_game()
	end
	
	animated_dinos:update(dt)

	local blockers: {ExplosionBlocking} = combine(
		eggs.on_ground, items.on_ground, soft_blocks.on_ground, pressure_blocks.on_ground
	)
	local explodables: {Explodable} = combine(
		players, soft_blocks.on_ground, eggs.on_ground, items.on_ground
	)
	bombs:update(dt, blockers, explodables)
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
	local function compare_player_y_pose(e1: Entity, e2: Entity): boolean
		return e1.position.y < e2.position.y
	end
	table.sort(players_to_sort, compare_player_y_pose)
end

local function get_avatar_position(avatar_num: number, num_avatars: number): Point
	local space_for_avatar = 35
	local x_start = 75
	local y_start = 3
	local avatar_space_padding = 10

	local total_space = MAP_WIDTH - x_start - avatar_space_padding
	local padding = (total_space - space_for_avatar * num_avatars) / (num_avatars + 1)
	local x_pos = x_start + padding * avatar_num + space_for_avatar * (avatar_num - 1)
	return Point.new(x_pos, y_start)
end

local function game_draw()
	lutro.graphics.draw(background)
	for _, block in ipairs(soft_blocks:not_exploding()) do
		block:draw()
	end
	
	game_timer:draw()

	for _, block in ipairs(pressure_blocks:falling()) do
		-- falling blocks are rendered last on top of everything,
		-- but their shadows have to be behind anything
		block:draw_shadow()
	end
	for _, block in ipairs(pressure_blocks.on_ground) do
		block:draw()
	end

	local dinos_drawn_with_player: {Dino} = {}
	local entities_to_draw: {Entity} = {}
	for _, player in ipairs(filter(players, is_alive)) do
		local player_animation = animations[player.id][player.state][player.action][player.direction]
		if player:is_invulnerable() and player.invulnerable_for % 0.3 < 0.15 then
			player_animation = animations_invulnerable[player.id][player.state][player.action][player.direction]
		end

		if player:is_riding_dino() then
			local dion_anim = animated_dinos:get_from(player.dino)
			table.insert(dinos_drawn_with_player, player.dino)
			table.insert(entities_to_draw, MountedPlayerAnimation.new(player_animation, dion_anim, player))
		else
			table.insert(entities_to_draw, PlayerAnimation.new(player_animation, player))
		end

		local avatar_pos = get_avatar_position(player.id, #players)
		local score_pos = avatar_pos:move(Vector.new(18, 5))
		lutro.graphics.draw(avatars[player.id], avatar_pos.x, avatar_pos.y)
		score_font:draw(tostring(player.score), score_pos)
	end

	for _, item in ipairs(items.on_ground) do
		table.insert(entities_to_draw, item)
	end
	for _, block in ipairs(pressure_blocks:falling()) do
		table.insert(entities_to_draw, block)
	end
	for _, egg in ipairs(eggs.on_ground) do
		table.insert(entities_to_draw, egg)
	end
	for dino, animation in pairs(animated_dinos:get_all_except(dinos_drawn_with_player)) do
		table.insert(entities_to_draw, MountAnimation.new(animation, dino))
	end

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
end

local function setup(selected_sprites: {CharacterSprite}): Scene
	setup_players(selected_sprites)

	local module = Scene.new()
	module.load = game_load
	module.update = game_update
	module.draw = game_draw
	return module
end

return setup
