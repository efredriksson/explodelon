require("const")
require("geometry")
require("player")
require("animation")
require("scene")
require("game_timer")
require("shade_font")
require("items")
require("level_map")
require("movement")
require("pressure_block")
require("eggs")

local function setup_players(number_players: integer): {Player}
	global players: {Player} = {}
	local start_by_id: {number:Point} = {
		[1] = Point.new(24, 32),
		[2] = Point.new(280, 32),
		[3] = Point.new(24, 192),
		[4] = Point.new(280, 192),
		[5] = Point.new(152, 112),
		[6] = Point.new(56, 112),
		[7] = Point.new(248, 112),
		[8] = Point.new(152, 192),
		[9] = Point.new(152, 32),
		[10] = Point.new(216, 160),
	}
	for i=1, number_players do
		table.insert(players, Player.new(i, start_by_id[i]))
	end

	return players
end

local function character_animation(asset_file: string): Animation
	return Animation.new(lutro.graphics.newImage(asset_file), 18, 34, 3, 18)
end

local function dino_animation(asset_file: string): Animation
	return Animation.new(lutro.graphics.newImage(asset_file), 34, 34, 3, 18)
end

local function character_avatar(character_asset: string): Image
	return lutro.graphics.newImage("assets/" .. character_asset .. "/avatar_neutral.png")
end

local function character_animation_for_action(character_asset: string, state: PlayerState, action: Action): {Direction: Animation}
	if state == "mounted" then
		if action == "jump" then
			-- Same sprite for 'jump' when on foot as when mounted
			state = "foot"
		elseif action == "idle" then
			-- Same sprite for 'idle' as 'walk' when mounted
			action = "walk"
		end
	end
	return {
		["up"] = character_animation("assets/" .. character_asset .. "/" .. state .. "/" .. action.. "_up.png"),
		["down"] = character_animation("assets/" .. character_asset .. "/" .. state .. "/" .. action.. "_down.png"),
		["right"] = character_animation("assets/" .. character_asset .. "/" .. state .. "/" .. action.. "_right.png"),
		["left"] = character_animation("assets/" .. character_asset .. "/" .. state .. "/" .. action.. "_left.png"),
	}
end

local function character_animations_for_state(character_asset: string, state: PlayerState): {Action: {Direction: Animation}}
	return {
		["walk"] = character_animation_for_action(character_asset, state, "walk"),
		["idle"] = character_animation_for_action(character_asset, state, "idle"),
		["jump"] = character_animation_for_action(character_asset, state, "jump"),
	}
end

local function character_animations(character_asset: string): {PlayerState: {Action: {Direction: Animation}}}
	return {
		["foot"] = character_animations_for_state(character_asset, "foot"),
		["mounted"] = character_animations_for_state(character_asset, "mounted"),
	}
end

local function dino_animation_for_action(action: Action, level: integer): {Direction: Animation}
	return {
		["up"] = dino_animation("assets/tirras/level_" .. level .. "/" .. action.. "_up.png"),
		["down"] = dino_animation("assets/tirras/level_" .. level .. "/" ..  action.. "_down.png"),
		["right"] = dino_animation("assets/tirras/level_" .. level .. "/" ..  action.. "_right.png"),
		["left"] = dino_animation("assets/tirras/level_" .. level .. "/" .. action.. "_left.png"),
	}
end

local function dino_animations_for_level(level: integer): {Action: {Direction: Animation}}
	return {
		["walk"] = dino_animation_for_action("walk", level),
		["idle"] = dino_animation_for_action("idle", level),
		["jump"] = dino_animation_for_action("idle", level),
	}
end

local function game_load()
	global background = lutro.graphics.newImage("assets/footboll-map.png")
	global animations: {integer: {PlayerState: {Action: {Direction: Animation}}}} = {
		[1] = character_animations("kotetsu"),
		[2] = character_animations("honey"),
		[3] = character_animations("kinu"),
		[4] = character_animations("milon"),
		[5] = character_animations("black"),
		[6] = character_animations("white"),
		[7] = character_animations("kabuki"),
		[8] = character_animations("master_higins"),
		[9] = character_animations("manjimaru"),
		[10] = character_animations("bonks"),
	}
	global dino_animations: {integer: {Action: {Direction: Animation}}} = 
	{
		[1] = dino_animations_for_level(1),
		[2] = dino_animations_for_level(2),
		[3] = dino_animations_for_level(3),
	}
	global avatars: {integer: Image} = {
		[1] = character_avatar("kotetsu"),
		[2] = character_avatar("honey"),
		[3] = character_avatar("kinu"),
		[4] = character_avatar("milon"),
		[5] = character_avatar("black"),
		[6] = character_avatar("white"),
		[7] = character_avatar("kabuki"),
		[8] = character_avatar("master_higins"),
		[9] = character_avatar("manjimaru"),
		[10] = character_avatar("bonks"),
	}

	load_egg_assets()
	global eggs = Eggs.new()
	eggs:spawn(Point.new(56, 64))

	load_item_assets()
	global items = Items.new()

	local time_left = 180
	global game_timer = GameTimer.new(time_left)
	game_timer:load_assets()

	load_pressure_block_assets()
	global pressure_blocks = PressureBlocks.new(time_left)

	global score_font = get_shaded_number_font()
end

local function get_available_item_spots(): {Point}
	-- Return places an item can drop, non-hard positions
	-- and also let's not drop items too close to players
	local available_spots: {Point} = {}

	for _, pos in ipairs(NON_HARD_POSITIONS) do
		local invalid_position = false
		for _, player in ipairs(players) do
			if player.position:distance_to(pos) < BLOCK_SIZE * 2 then
				invalid_position = true
			end
		end

		for _, pressure_block in ipairs(pressure_blocks.on_ground) do
			if pressure_block.position:equal(pos) then
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
	setup_players(#old_player_datas)
	transfere_player_data(old_player_datas)
	game_load()
end

local function clear_items(hitting_ground: {PressureBlock})
	for _, block in ipairs(hitting_ground) do
		for j, item in ipairs(items.on_ground) do
			if item.position:equal(block.position) then
				table.remove(items.on_ground, j)
			end
		end
	end
end

local function game_update(dt: number)
	local hitting_ground = pressure_blocks:update(dt)
	local alive_players: {Player} = {}

	for _, player in ipairs(players) do
		player:update(dt)
		if player.action ~= "jump" then
			set_position_and_dir_from_input(player, dt, pressure_blocks:hitboxes())
		end

		animations[player.id][player.state][player.action][player.direction]:update(dt)
		if player.state == "mounted" then
			dino_animations[player.dino_level][player.action][player.direction]:update(dt)
		end

		for j, item in ipairs(items.on_ground) do
			if item.position:in_radius_of(player.position, BLOCK_SIZE / 2) then
				items:consumed_by_player(player, j)
			end
		end

		local egg_position = eggs:possible_hatcher_at(player.position)
		if egg_position then
			player:jumps_to(egg_position)
		end

		local player_hitbox = new_hit_box(player.position)
		for _, block in ipairs(hitting_ground) do
			local block_hitbox = new_hit_box(block.position)
			if player_hitbox:center_distance(block_hitbox) < BLOCK_SIZE / 2 then
				player.is_alive = false
			end
		end

		if player.is_alive then
			table.insert(alive_players, player)
		end
	end

	items:update(dt)
	items:dropNew(get_available_item_spots())
	clear_items(hitting_ground)

	local out_of_time = game_timer:decrement(dt)
	if #alive_players == 1 then
		alive_players[1]:won_game()
		next_game()
	end
	if #alive_players == 0 or out_of_time then
		next_game()
	end

	eggs:update(dt)
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
	game_timer:draw()

	for _, block in ipairs(pressure_blocks:falling()) do
		-- falling blocks are rendered last on top of everything,
		-- but their shadows have to be behind anything
		block:draw_shadow()
	end

	for _, block in ipairs(pressure_blocks.on_ground) do
		block:draw()
	end

	local entities_to_draw: {Entity} = {}
	for _, player in ipairs(players) do
		local player_animation = animations[player.id][player.state][player.action][player.direction]
	
		if player.state == "mounted" then
			local dion_anim = dino_animations[player.dino_level][player.action][player.direction]
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

	-- Need to render entities in the front last so they are on top of any other entity
	sort_entities_by_y_cord(entities_to_draw)
	for _, entity in ipairs(entities_to_draw) do
		entity:draw()
	end
end

local function setup(number_players: integer): Scene
	setup_players(number_players)

	local module = Scene.new()
	module.load = game_load
	module.update = game_update
	module.draw = game_draw
	return module
end

return setup
