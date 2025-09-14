require("const")

local WIDTH = 320
local HEIGHT = 224
local BLOCK_SIZE = 16
local PLAYER_SPEED = 40

local record Point
   x: number
   y: number
end

local record Rectangle
	x: number
	y: number
	width: number
	height: number
end

local function get_hard_blocks(): {Rectangle}
	local blocks: {Rectangle} = {}

	local function hard_block(i: number, j: number): Rectangle
		return {
			x=24 + BLOCK_SIZE + i * 2 * BLOCK_SIZE,
			y=32 + BLOCK_SIZE + j * 2 * BLOCK_SIZE,
			width=BLOCK_SIZE,
			height=BLOCK_SIZE
		}
	end

	for i=0, 7 do
		for j=0, 4 do
			table.insert(blocks, hard_block(i, j))
		end
	end
	return blocks
end

local record Player
	id: integer
   	position: Point
	asset_file: string
end

local PLAYER_AREA: Rectangle = {x=24, y=32, width=272, height=176}
local HARD_BLOCKS = get_hard_blocks()

local function interval_overlap(xmin1: number, xmax1: number, xmin2: number, xmax2: number): boolean
	return xmax1 >= xmin2 and xmax2 >= xmin1
end

local function box_overlap(b1: Rectangle, b2: Rectangle): boolean
	return interval_overlap(b1.x, b1.x + b1.width, b2.x, b2.x + b2.width) and
		interval_overlap(b1.y, b1.y + b1.height, b2.y, b2.y + b2.height)
end

local function interval_contained(xmin1: number, xmax1: number, xmin2: number, xmax2: number): boolean
	return xmin1 >= xmin2 and xmax1 <= xmax2
end

local function box_contains(small: Rectangle, large: Rectangle): boolean
	return interval_contained(small.x, small.x + small.width, large.x, large.x + large.width) and
		interval_contained(small.y, small.y + small.height, large.y, large.y + large.height)
end

local function valid_player_move(new_position: Point): boolean
	local new_hitbox: Rectangle = {x = new_position.x, y=new_position.y, height=BLOCK_SIZE-1, width=BLOCK_SIZE-1}
	for i=1, #HARD_BLOCKS do
		local hard_block = HARD_BLOCKS[i]
		if box_overlap(new_hitbox, hard_block) then
			return false
		end
	end

	return box_contains(new_hitbox, PLAYER_AREA)
end

function lutro.conf(t: Configuration)
	t.width  = WIDTH
	t.height = HEIGHT
end

local function convert_pos_for_character_draw(image: Image, pos: Point): Point
	local h = image:getHeight()
	-- x: -1 and y: +1 is because of the sprite, look over when doing animations
	return {x=pos.x - 1, y=pos.y - h + BLOCK_SIZE + 1}
end

local function setup_players(): {Player}
	local players: {Player} = {}
	local asset_by_id: {number:string} = {
		[1] = "assets/kotetsu.png",
		[2] = "assets/honey.png",
		[3] = "assets/kinu.png",
		[4] = "assets/milon.png",
	}
	local start_by_id: {number:Point} = {
		[1] = {x=24, y=32},
		[2] = {x=280, y=32},
		[3] = {x=24, y=192},
		[4] = {x=280, y=192},
	}
	for i=1, 4 do
		table.insert(players, {id=i, position=start_by_id[i], asset_file=asset_by_id[i]})
	end

	return players
end

function lutro.load()
	global background = lutro.graphics.newImage("assets/footboll-map.png")
	global players = setup_players()
end

local function get_new_position_from_input(player: Player, dt: number): Point
	-- Create copy of player position that we mutate before returning as 'new'
	local cur_pos: Point = {x = player.position.x, y = player.position.y}

	local function try_update_to(new_potential: Point)
		if valid_player_move(new_potential) then
			cur_pos = new_potential
		end
	end

	if lutro.joystick.isDown(player.id, JOYPAD_DOWN) then
		try_update_to({x=cur_pos.x, y=cur_pos.y + dt * PLAYER_SPEED})
	end
	if lutro.joystick.isDown(player.id, JOYPAD_UP) then
		try_update_to({x=cur_pos.x, y=cur_pos.y - dt * PLAYER_SPEED})
	end
	if lutro.joystick.isDown(player.id, JOYPAD_RIGHT) then
		try_update_to({x=cur_pos.x + dt * PLAYER_SPEED, y=cur_pos.y})
	end
	if lutro.joystick.isDown(player.id, JOYPAD_LEFT) then
		try_update_to({x=cur_pos.x - dt * PLAYER_SPEED, y=cur_pos.y})
	end

	return cur_pos
end

function lutro.update(dt: number)
	for i=1, #players do
		local player = players[i]
		local new_position = get_new_position_from_input(player, dt)
		player.position = new_position
	end
end

function lutro.draw()
	lutro.graphics.draw(background)
	for i=1, #players do
		local player = players[i]
		local player_img = lutro.graphics.newImage(player.asset_file)
		local adj_pos = convert_pos_for_character_draw(player_img, player.position)
		lutro.graphics.draw(player_img, adj_pos.x, adj_pos.y)
	end
end
