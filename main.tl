require("const")
require("geometry")
require("player")
require("animation")

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

function lutro.conf(t: Configuration)
	t.width  = MAP_WIDTH
	t.height = MAP_HEIGHT
end

local function convert_pos_for_character_draw(animation: Animation, pos: Point): Point
	local h = animation.image:getHeight()
	-- x: -1 and y: +1 is because of the sprite, look over when doing animations
	return Point.new(pos.x - 1, pos.y - h + BLOCK_SIZE + 1)
end

local function setup_players(): {Player}
	local players: {Player} = {}
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
	local num_joysticks = lutro.joystick.getJoystickCount()
	for i=1, num_joysticks do
		table.insert(players, {id=i, position=start_by_id[i]})
	end

	return players
end

local function character_animation(asset_file: string): Animation
	return Animation.new(lutro.graphics.newImage(asset_file), 18, 34, 3, 18)
end

function lutro.load()
	global background = lutro.graphics.newImage("assets/footboll-map.png")
	global players = setup_players()
	global animations: {number: Animation} = {
		[1] = character_animation("assets/kotetsu_walk_down.png"),
		[2] = character_animation("assets/honey_walk_down.png"),
		[3] = character_animation("assets/kinu_walk_down.png"),
		[4] = character_animation("assets/milon_walk_down.png"),
		[5] = character_animation("assets/black_walk_down.png"),
		[6] = character_animation("assets/white_walk_down.png"),
		[7] = character_animation("assets/kabuki_walk_down.png"),
		[8] = character_animation("assets/master_higins_walk_down.png"),
		[9] = character_animation("assets/manjimaru_walk_down.png"),
		[10] = character_animation("assets/bonks_walk_down.png"),
	}
end

local function get_new_position_from_input(player: Player, dt: number): Point
	-- Create copy of player position that we mutate before returning as 'new'
	local cur_pos = Point.new(player.position.x, player.position.y)

	local function try_update_to(new_potential: Point)
		if valid_player_move(new_potential) then
			cur_pos = new_potential
		end
	end

	if lutro.joystick.isDown(player.id, JOYPAD_DOWN) then
		try_update_to(Point.new(cur_pos.x, cur_pos.y + dt * PLAYER_SPEED))
	end
	if lutro.joystick.isDown(player.id, JOYPAD_UP) then
		try_update_to(Point.new(cur_pos.x, cur_pos.y - dt * PLAYER_SPEED))
	end
	if lutro.joystick.isDown(player.id, JOYPAD_RIGHT) then
		try_update_to(Point.new(cur_pos.x + dt * PLAYER_SPEED, cur_pos.y))
	end
	if lutro.joystick.isDown(player.id, JOYPAD_LEFT) then
		try_update_to(Point.new(cur_pos.x - dt * PLAYER_SPEED, cur_pos.y))
	end

	return cur_pos
end

function lutro.update(dt: number)
	for i=1, #players do
		local player = players[i]
		local new_position = get_new_position_from_input(player, dt)
		player.position = new_position

		animations[player.id]:update(dt)
	end
end

function lutro.draw()
	lutro.graphics.draw(background)
	for i=1, #players do
		local player = players[i]
		local player_animation = animations[player.id]
		local adj_pos = convert_pos_for_character_draw(player_animation, player.position)
		player_animation:draw(adj_pos.x, adj_pos.y)
	end
end
