require("const")
require("geometry")
require("player")
require("animation")
require("scene")
require("game_timer")
require("shade_font")

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

local function valid_player_move(new_position: Point): boolean
	local new_hitbox = new_hit_box(new_position)
	for i=1, #HARD_BLOCKS do
		if new_hitbox:overlap(HARD_BLOCKS[i]) then
			return false
		end
	end

	return PLAYER_AREA:contains(new_hitbox)
end

local function convert_pos_for_character_draw(animation: Animation, pos: Point): Point
	local h = animation.image:getHeight()
	-- x: -1 and y: +1 is because of the sprite, look over when doing animations
	return Point.new(pos.x - 1, pos.y - h + BLOCK_SIZE + 1)
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

	global game_timer = GameTimer.new(180)
	game_timer:load_assets()

	global score_font = get_shaded_number_font()
end

local function get_directions_from_input(id: integer, dt: number): {{Vector, Direction}}
	local result: {{Vector, Direction}} = {}

	if lutro.joystick.isDown(id, JOYPAD_DOWN) then
		table.insert(result, {Vector.new(0, dt * PLAYER_SPEED), "down"})
	end
	if lutro.joystick.isDown(id, JOYPAD_UP) then
		table.insert(result, {Vector.new(0, -dt * PLAYER_SPEED), "up"})
	end
	if lutro.joystick.isDown(id, JOYPAD_RIGHT) then
		table.insert(result, {Vector.new(dt * PLAYER_SPEED, 0), "right"})
	end
	if lutro.joystick.isDown(id, JOYPAD_LEFT) then
		table.insert(result, {Vector.new(-dt * PLAYER_SPEED, 0), "left"})
	end

	return result
end

local function set_position_and_dir_from_input(player: Player, dt: number)
	local directions = get_directions_from_input(player.id, dt)
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
	end

	game_timer:decrement(dt)
end

local function sort_players_by_y_cord(players_to_sort: {Player})
	local function compare_player_y_pose(p1: Player, p2: Player): boolean
		return p1.position.y < p2.position.y
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

	 -- Need to render characters in the front last so they are on top of any other entity
	sort_players_by_y_cord(players)
	for _, player in ipairs(players) do
		local player_animation = animations[player.id][player.direction]
		local draw_pos = convert_pos_for_character_draw(player_animation, player.position)
		player_animation:draw(draw_pos.x, draw_pos.y)
	
		local avatar_pos = get_avatar_position(player.id, #players)
		local score_pos = avatar_pos:move(Vector.new(18, 5))
		lutro.graphics.draw(avatars[player.id], avatar_pos.x, avatar_pos.y)
		score_font:draw(tostring(player.score), score_pos)
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
