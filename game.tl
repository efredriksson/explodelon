require("const")
require("geometry")
require("player")
require("animation")
require("scene")
require("game_timer")
require("shade_font")
require("items")

local function get_hard_blocks(): {Rectangle}
	local blocks: {Rectangle} = {}

	local function hard_block(i: number, j: number): Rectangle
		return Rectangle.new(
			24 + BLOCK_SIZE + i * 2 * BLOCK_SIZE,
			32 + BLOCK_SIZE + j * 2 * BLOCK_SIZE,
			BLOCK_SIZE,
			BLOCK_SIZE
		)
	end

	for i=0, 7 do
		for j=0, 4 do
			table.insert(blocks, hard_block(i, j))
		end
	end
	return blocks
end

local PLAYER_AREA = Rectangle.new(24, 32, 272, 176)
local HARD_BLOCKS = get_hard_blocks()

local function get_non_hard_block_positions(): {Point}
	local positions: {Point} = {}

	local function get_block(i: number, j: number): Point
		return Point.new(
			24 + i * BLOCK_SIZE,
			32 + j * BLOCK_SIZE
		)
	end

	for i=0, 16 do
		for j=0, 10 do
			local block = get_block(i, j)
			local is_hard_block = false
			for _, hard_block in ipairs(HARD_BLOCKS) do
				if hard_block.x == block.x and hard_block.y == block.y then
					is_hard_block = true
				end
			end
			
			if not is_hard_block then
				table.insert(positions, block)
			end
		end
	end
	return positions
end

local NON_HARD_POSITIONS = get_non_hard_block_positions()

local function valid_player_move(new_position: Point): boolean
	local new_hitbox = new_hit_box(new_position)
	for i=1, #HARD_BLOCKS do
		if new_hitbox:overlap(HARD_BLOCKS[i]) then
			return false
		end
	end

	return PLAYER_AREA:contains(new_hitbox)
end

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

local function character_avatar(character_asset: string): Image
	return lutro.graphics.newImage("assets/" .. character_asset .. "/avatar_neutral.png")
end

local function character_animations(character_asset: string): {Direction: Animation}
	return {
		["up"] = character_animation("assets/" .. character_asset .. "/walk_up.png"),
		["down"] = character_animation("assets/" .. character_asset .. "/walk_down.png"),
		["right"] = character_animation("assets/" .. character_asset .. "/walk_right.png"),
		["left"] = character_animation("assets/" .. character_asset .. "/walk_left.png"),
	}
end

local function get_available_item_spots(): {Point}
	-- Return places an item can drop, non-hard positions
	-- and also let's not drop items too close to players
	local available_spots: {Point} = {}

	for _, pos in ipairs(NON_HARD_POSITIONS) do
		local to_close_to_player = false
		for _, player in ipairs(players) do
			if math.abs(player.position.x - pos.x) + math.abs(player.position.y - pos.y) < 32 then
				to_close_to_player = true
			end
		end

		if not to_close_to_player then
			table.insert(available_spots, pos)
		end
	end

	return available_spots
end

local function game_load()
	global background = lutro.graphics.newImage("assets/footboll-map.png")
	global animations: {number: {Direction: Animation}} = {
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
	global avatars: {number: Image} = {
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

	load_item_assets()
	global items = Items.new()

	global game_timer = GameTimer.new(180)
	game_timer:load_assets()

	global score_font = get_shaded_number_font()
end

local function get_directions_from_input(player: Player, dt: number): {{Vector, Direction}}
	local result: {{Vector, Direction}} = {}

	if lutro.joystick.isDown(player.id, JOYPAD_DOWN) then
		table.insert(result, {Vector.new(0, dt * player.speed), "down"})
	end
	if lutro.joystick.isDown(player.id, JOYPAD_UP) then
		table.insert(result, {Vector.new(0, -dt * player.speed), "up"})
	end
	if lutro.joystick.isDown(player.id, JOYPAD_RIGHT) then
		table.insert(result, {Vector.new(dt * player.speed, 0), "right"})
	end
	if lutro.joystick.isDown(player.id, JOYPAD_LEFT) then
		table.insert(result, {Vector.new(-dt * player.speed, 0), "left"})
	end

	return result
end

local function set_position_and_dir_from_input(player: Player, dt: number)
	local directions = get_directions_from_input(player, dt)
	for i=1, #directions do
		-- Set direction for any input direction as default
		player.direction = directions[i][2]
	end

	for i=1, #directions do
		local new_position = player.position:move(directions[i][1])
		if valid_player_move(new_position) then
			player.position = new_position
			-- Direction for valid moves takes precedence however!
			player.direction = directions[i][2]
		end
	end

	player.idle = #directions == 0
end

local function game_update(dt: number)
	for i=1, #players do
		local player = players[i]
		set_position_and_dir_from_input(player, dt)

		local animation = animations[player.id][player.direction]
		if player.idle then
			animation.playing = false
			animation.timer = 8 -- hack, this forces final animation fram, which is 'idle'
		else
			animation.playing = true
		end
		animations[player.id][player.direction]:update(dt)

		for j, item in ipairs(items.on_ground) do
			if item.position:in_radius_of(player.position, BLOCK_SIZE / 2) then
				items:consumed_by_player(player, j)
			end
		end
	end

	items:update(dt)
	items:dropNew(get_available_item_spots())
	game_timer:decrement(dt)
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

	local entities_to_draw: {Entity} = {}
	for _, player in ipairs(players) do
		local player_animation = animations[player.id][player.direction]
		table.insert(entities_to_draw, PlayerAnimation.new(player_animation, player.position))
	
		local avatar_pos = get_avatar_position(player.id, #players)
		local score_pos = avatar_pos:move(Vector.new(18, 5))
		lutro.graphics.draw(avatars[player.id], avatar_pos.x, avatar_pos.y)
		score_font:draw(tostring(player.score), score_pos)
	end

	for _, item in ipairs(items.on_ground) do
		table.insert(entities_to_draw, item)
	end

	-- Need to render entities in the front last so they are on top of any other entity
	sort_entities_by_y_cord(entities_to_draw)
	for _, entity in ipairs(entities_to_draw) do
		entity:draw()
	end

	game_timer:draw()
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
