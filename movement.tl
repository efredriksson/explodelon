require("const")
require("geometry")
require("level_map")
require("player")

local record Movement
	dxdy: Vector
	dir: Direction
end

function Movement.new(dxdy: Vector, dir: Direction): Movement
   local self: Movement = setmetatable({}, { __index = Movement })
   self.dir = dir
   self.dxdy = dxdy
   return self
end

local function get_directions_from_input(player: Player, dt: number): {Movement}
	local result: {Movement} = {}

	if lutro.joystick.isDown(player.id, JOYPAD_DOWN) then
		table.insert(result, Movement.new(Vector.new(0, dt * player.speed), "down"))
	end
	if lutro.joystick.isDown(player.id, JOYPAD_UP) then
		table.insert(result, Movement.new(Vector.new(0, -dt * player.speed), "up"))
	end
	if lutro.joystick.isDown(player.id, JOYPAD_RIGHT) then
		table.insert(result, Movement.new(Vector.new(dt * player.speed, 0), "right"))
	end
	if lutro.joystick.isDown(player.id, JOYPAD_LEFT) then
		table.insert(result, Movement.new(Vector.new(-dt * player.speed, 0), "left"))
	end

	return result
end

local function valid_player_move(new_position: Point): boolean
	local new_hitbox = new_hit_box(new_position)
	for i=1, #HARD_BLOCKS do
		if new_hitbox:overlap(HARD_BLOCKS[i]) then
			return false
		end
	end

	return PLAYER_AREA:contains(new_hitbox)
end

local function get_new_player_orientation(player_dir: Direction, player_pos: Point, directions: {Movement}): Direction, Point
	for _, direction in ipairs(directions) do
		-- Set direction for any input direction as default
		player_dir = direction.dir
	end

	for _, direction in ipairs(directions) do
		local new_position = player_pos:move(direction.dxdy)
		if valid_player_move(new_position) then
			player_pos = new_position
			-- Direction for valid moves takes precedence however!
			player_dir = direction.dir
		end
	end

	return player_dir, player_pos
end

global function set_position_and_dir_from_input(player: Player, dt: number)
	local directions = get_directions_from_input(player, dt)
	player.direction, player.position = get_new_player_orientation(
		player.direction, player.position, directions
	)
	player.idle = #directions == 0
end
