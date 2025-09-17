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
		table.insert(players, {id=i, position=start_by_id[i], direction="down"})
	end

	return players
end

local function character_animation(asset_file: string): Animation
	return Animation.new(lutro.graphics.newImage(asset_file), 18, 34, 3, 18)
end

local function character_animations(character_asset: string): {Direction: Animation}
	return {
		["up"] = character_animation("assets/" .. character_asset .. "_walk_up.png"),
		["down"] = character_animation("assets/" .. character_asset .. "_walk_down.png"),
		["right"] = character_animation("assets/" .. character_asset .. "_walk_right.png"),
		["left"] = character_animation("assets/" .. character_asset .. "_walk_left.png"),
	}
end



function lutro.load()
	global background = lutro.graphics.newImage("assets/footboll-map.png")
	global players = setup_players()
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
		local new_position = player.position:move(directions[i][1])
		if valid_player_move(new_position) then
			player.position = new_position
			player.direction = directions[i][2]
		end
	end
end

function lutro.update(dt: number)
	for i=1, #players do
		local player = players[i]
		set_position_and_dir_from_input(player, dt)

		animations[player.id][player.direction]:update(dt)
	end
end

function lutro.draw()
	lutro.graphics.draw(background)
	for i=1, #players do
		local player = players[i]
		local player_animation = animations[player.id][player.direction]
		local adj_pos = convert_pos_for_character_draw(player_animation, player.position)
		player_animation:draw(adj_pos.x, adj_pos.y)
	end
end
