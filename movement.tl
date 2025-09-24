require("const")
require("geometry")
require("level_map")
require("player")

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

local function valid_player_move(new_position: Point): boolean
	local new_hitbox = new_hit_box(new_position)
	for i=1, #HARD_BLOCKS do
		if new_hitbox:overlap(HARD_BLOCKS[i]) then
			return false
		end
	end

	return PLAYER_AREA:contains(new_hitbox)
end

global function set_position_and_dir_from_input(player: Player, dt: number)
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
