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


local function restrict_player_movement(new_position: Point, movement: Vector): Point, boolean, boolean, boolean
	local new_hitbox = new_hit_box(new_position)
	local corner_fix = 8
	for _, hard_block in ipairs(HARD_BLOCKS) do
		if new_hitbox:overlap(hard_block) then
			if movement.x == 0 then
				local x_dist = BLOCK_SIZE - math.abs(new_position.x - hard_block.x)
				if movement.y < 0 then
					--print("Restricted (block): x = 0, y < 0", new_position.x, new_position.y)
					if x_dist > corner_fix then
						return Point.new(new_position.x, hard_block.y + BLOCK_SIZE), true, false, false
					else
						local dy = math.abs(movement.y)
						local dx = math.min(x_dist, dy)
						dy = (movement.y / dy) * (dy - dx)
						--print("DX ", dx)
						if math.abs(new_position.x + BLOCK_SIZE - hard_block.x) < corner_fix * 2 then
							return Point.new(new_position.x - dx, new_position.y + dy), true, true, true
						else
							return Point.new(new_position.x + dx, new_position.y + dy), true, true, true
						end
					end
				else
					--print("Restricted (block): x = 0, y > 0", new_position.x, new_position.y)
					if x_dist > corner_fix then
						return Point.new(new_position.x, hard_block.y - BLOCK_SIZE), true, false, false
					else
						local dy = math.abs(movement.y)
						local dx = math.min(x_dist, dy)
						dy = (movement.y / dy) * (dy - dx)
						--print("DX ", dx)
						if math.abs(new_position.x + BLOCK_SIZE - hard_block.x) < corner_fix * 2 then
							return Point.new(new_position.x - dx, new_position.y + dy), true, true, true
						else
							return Point.new(new_position.x + dx, new_position.y + dy), true, true, true
						end
					end
				end
			elseif movement.y == 0 then
				local y_dist = BLOCK_SIZE - math.abs(new_position.y - hard_block.y)
				if movement.x < 0 then
					--print("Restricted (block): y = 0, x < 0", new_position.x, new_position.y)
					if y_dist > corner_fix then
						return Point.new(hard_block.x + BLOCK_SIZE, new_position.y), true, false, false
					else
						local dx = math.abs(movement.x)
						local dy = math.min(y_dist, dx)
						dx = (movement.x / dx) * (dx - dy)
						if math.abs(new_position.y + BLOCK_SIZE - hard_block.y) < corner_fix * 2 then
							return Point.new(new_position.x + dx, new_position.y - dy), true, true, true
						else
							return Point.new(new_position.x + dx, new_position.y + dy), true, true, true
						end
					end
				else
					--print("Restricted (block): y = 0, x > 0", new_position.x, new_position.y)
					if y_dist > corner_fix then
						return Point.new(hard_block.x - BLOCK_SIZE, new_position.y), true, false, false
					else
						local dx = math.abs(movement.x)
						local dy = math.min(y_dist, dx)
						dx = (movement.x / dx) * (dx - dy)
						if math.abs(new_position.y + BLOCK_SIZE - hard_block.y) < corner_fix * 2 then
							return Point.new(new_position.x + dx, new_position.y - dy), true, true, true
						else
							return Point.new(new_position.x + dx, new_position.y + dy), true, true, true
						end
					end
				end
			else
				assert(false, "Unknown movement vector")
			end
		end
	end
	if not PLAYER_AREA:contains(new_hitbox) then
		if movement.x == 0 then
			if movement.y < 0 then
				--print("Restricted (area): x = 0, y < 0", new_position.x, new_position.y)
				return Point.new(new_position.x, PLAYER_AREA.y), true, false, false
			else
				--print("Restricted (area): x = 0, y > 0", new_position.x, new_position.y)
				return Point.new(new_position.x, PLAYER_AREA.y + PLAYER_AREA.height - BLOCK_SIZE), true, false, false
			end
		elseif movement.y == 0 then
			if movement.x < 0 then
				--print("Restricted (area): y = 0, x < 0", new_position.x, new_position.y)
				return Point.new(PLAYER_AREA.x, new_position.y), true, false, false
			else
				--print("Restricted (area): y = 0, x > 0", new_position.x, new_position.y)
				return Point.new(PLAYER_AREA.x + PLAYER_AREA.width - BLOCK_SIZE, new_position.y), true, false, false
			end
		else
			assert(false, "Unknown movement vector")
		end
	end

	--print("Unrestricted new position ", new_position.x, new_position.y)
	return new_position, false, true, false
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
	local cuts_corners = false
	local _1: Point
	local _2: boolean
	local _3: boolean

	if #directions > 0 then
		print("start of direction logic:")
		local local_x_pos = math.fmod(player.position.x  - PLAYER_AREA.x, BLOCK_SIZE)
		local local_y_pos = math.fmod(player.position.y  - PLAYER_AREA.y, BLOCK_SIZE)
		local x_peek_in = local_x_pos <= BLOCK_SIZE / 2 and local_x_pos > 0
		local y_peek_in = local_y_pos <= BLOCK_SIZE / 2 and local_y_pos > 0
		print("Displacement", local_x_pos, y_peek_in, local_y_pos, x_peek_in)
	end

	-- TODO: Rename method, at entrance and trying to exit it?
	local function at_corridor_entrance_trying_to_exit(pos: Point, press_dir: Direction): boolean
		local local_x_pos = math.fmod(pos.x  - PLAYER_AREA.x, BLOCK_SIZE)
		local local_y_pos = math.fmod(pos.y  - PLAYER_AREA.y, BLOCK_SIZE)
		
		
		if local_x_pos == 0 and local_y_pos > 0 then
			return press_dir == "left" or press_dir == "right"
		end 

		if local_y_pos == 0 and local_x_pos > 0 then
			return press_dir == "up" or press_dir == "down"
		end

		return false

		--local x_dir_displasement = math.abs(local_x_pos - BLOCK_SIZE / 2) > 2 and local_x_pos > 0
		--local y_dir_displasement = math.abs(local_y_pos - BLOCK_SIZE / 2) > 2 and local_y_pos > 0
		--local x_dir_displasement = local_x_pos < BLOCK_SIZE - 1e-10 and local_x_pos > 1e-10
		--local y_dir_displasement = local_y_pos < BLOCK_SIZE - 1e-10 and local_y_pos > 1e-10
		--if press_dir == "down" and x_dir_displasement then
		--	return true
		--elseif press_dir == "up" and x_dir_displasement then
		--	return true
		--elseif press_dir == "right" and y_dir_displasement then
		--	return true
		--elseif press_dir == "left" and y_dir_displasement then
		--	return true
		--else
		--	return false
		--end
	end

	local function direction_val(d: {Vector, Direction}): integer
		-- TODO: Need to make sure that we take directions that would cause
		-- corner cutting while we have just entered a corridor absolutely last!
		-- This makes sense because having entered something you probably want to
		-- stay in it and have the game help with this

		local movement = d[1]
		local trying_to_exit_corridor = at_corridor_entrance_trying_to_exit(player.position, d[2])
		local new_position = player.position:move(movement)
		_1, _2, _3, cuts_corners = restrict_player_movement(new_position, movement)

		local keep_cur_dir = d[2] == player.direction

		local local_x_pos = math.fmod(player.position.x  - PLAYER_AREA.x, BLOCK_SIZE)
		local local_y_pos = math.fmod(player.position.y  - PLAYER_AREA.y, BLOCK_SIZE)
		if d[2] == "down" and local_y_pos > BLOCK_SIZE / 2 then
			return 5
		end
		if d[2] == "up" and local_y_pos < BLOCK_SIZE / 2 and local_y_pos > 0 then
			return 5
		end
		if d[2] == "right" and local_x_pos > BLOCK_SIZE / 2 then
			return 5
		end
		if d[2] == "left" and local_x_pos < BLOCK_SIZE / 2 and local_x_pos > 0 then
			return 5
		end

		-- Lowest priority, try cut corner when at entrance last!
		if trying_to_exit_corridor then
			return 4
		end

		-- priority for going another direction than currently in
		if keep_cur_dir then
			return 3
		end

		-- Highest prioriy direction!
		if cuts_corners then
			return 2
		end

		-- Highest prioriy direction!
		return 1
	end

	local function sort_directions_by_prio(directions_to_sort: {{Vector, Direction}})
		local function compare_player_y_pose(e1: {Vector, Direction}, e2: {Vector, Direction}): boolean
			return direction_val(e1) < direction_val(e2)
		end
		table.sort(directions_to_sort, compare_player_y_pose)
	end

	-- Prioritize directions that are different from current first
	local directions_reorder: {{Vector, Direction}} = {}
	for _, direction in ipairs(directions) do
		table.insert(directions_reorder, direction)
	end
	sort_directions_by_prio(directions_reorder)

	local has_set_player_direction = false

	for _, direction in ipairs(directions_reorder) do
		print("Direction value found: " .. direction_val(direction))
	end

	for _, direction in ipairs(directions_reorder) do
		print("Using direction value: " .. direction_val(direction))
		local movement = direction[1]
		local new_position = player.position:move(movement)
		local restricted = false
		local full_movement = false
		player.position, restricted, full_movement, cuts_corners = restrict_player_movement(new_position, movement)
		if not restricted then
			-- Direction for valid moves takes precedence however!
			player.direction = direction[2]
			has_set_player_direction = true
		elseif not has_set_player_direction then
			player.direction = direction[2]
		end
		if full_movement then
			break -- All speed have been used up!
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
