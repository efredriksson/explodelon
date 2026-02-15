local animations = require("engine.animations")
local characters = require("characters")
local dinos = require("dinos")
local dino_animations = require("dino_animations")
local grid = require("level_layout.grid")
local images = require("engine.images")
local itertools = require("itertools")
local players = require("players")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local z_index = require("z_index")

local type Entity = require("engine.entity")
local type Animation = animations.Animation
local type Action = players.Action
local type CharacterName = characters.CharacterName
local type AnimatedDinos = dino_animations.AnimatedDinos
local type Dino = dinos.Dino
local type Player = players.Player
local type PlayerState = players.PlayerState
local type Direction = vectors.Direction
local type Point = points.Point
local type Rectangle = rectangles.Rectangle
local type Vector = vectors.Vector
local type SpriteImages = {PlayerState: {Action: {Direction: Image}}}
local type SonicWaveColor = players.SonicWaveColor

local jump_shadow_image: Image
local sonic_wave_images: {Direction: {SonicWaveColor: Image}} = {}
local stun_cry_text_images: {Direction: {integer: Image}}
local sprites: {CharacterName: SpriteImages} = {}
local sprites_invulnerable: {CharacterName: SpriteImages} = {}
local special_animation_frame_durations: {Action: number} = {
	dying = 1 / 8,
	stunned = 1 / 8,
	crashed = 1 / 8,
}

local function get_animation_frame_duration(action: Action): number
	local default_frame_duration = 1 / 6
	return special_animation_frame_durations[action] or default_frame_duration
end

local function get_sprite_set(
	character_asset: CharacterName, invulnerable: boolean
): SpriteImages
	if invulnerable then
		return sprites_invulnerable[character_asset]
	else
		return sprites[character_asset]
	end
end

local function character_animation(character_asset: CharacterName, invulnerable: boolean): {PlayerState: {Action: {Direction: Animation}}}
	local resolved_sprites = get_sprite_set(character_asset, invulnerable)
	local character_animations: {PlayerState: {Action: {Direction: Animation}}} = {}
	for state, by_action in pairs(resolved_sprites) do
		character_animations[state] = {}
		for action, by_direction in pairs(by_action) do
			character_animations[state][action] = {}
			local frame_duration = get_animation_frame_duration(action)
			for direction, sprite_image in pairs(by_direction) do
				character_animations[state][action][direction] = animations.new(sprite_image, 18, frame_duration)
			end
		end
	end

	return character_animations
end

local record PlayerAnimation is Entity
	player: Player
	draw_position: Point
	animation: Animation
end

function PlayerAnimation.new(animation: Animation, player: Player): PlayerAnimation
	local self: PlayerAnimation = setmetatable({}, { __index = PlayerAnimation })
	self.z_index = z_index.LEVEL
	self.animation = animation
	self.player = player
	self.draw_position = player:get_draw_position()
	return self
end

function PlayerAnimation:get_position(): Point
    return self.player.position
end

function PlayerAnimation:hitbox(): Rectangle
    return self.player:hitbox()
end

local function block_to_anim_draw_pos(animation: Animation, pos: Point): Point
	-- y: +1 is because of the sprite, look over when doing animations
	return points.new(
		pos.x + (grid.TILE_SIZE - animation.width) / 2,
		pos.y - animation.height + grid.TILE_SIZE + 1)
end

function PlayerAnimation:draw()
	local draw_pos = block_to_anim_draw_pos(self.animation, self.draw_position)
	self.animation:draw(draw_pos.x, draw_pos.y)
end

local record MountAnimation is Entity
	dino: Dino
	animation: Animation
end

function MountAnimation.new(animation: Animation, dino: Dino): MountAnimation
	local self: MountAnimation = setmetatable({}, { __index = MountAnimation })
	self.z_index = z_index.LEVEL
	self.dino = dino
	self.animation = animation
	return self
end

function MountAnimation:get_position(): Point
    return self.dino.position
end

function MountAnimation:hitbox(): Rectangle
    return self.dino:hitbox()
end

function MountAnimation:draw()
	local draw_pos = block_to_anim_draw_pos(self.animation, self.dino.position)
	self.animation:draw(draw_pos.x, draw_pos.y)
end

local record MountedPlayerAnimation is Entity
	player: Player
	draw_position: Point
	player_animation: Animation
	dino_animation: Animation
end

function MountedPlayerAnimation.new(
	player_animation: Animation, dino_animation: Animation, player: Player
): MountedPlayerAnimation
	local self: MountedPlayerAnimation = setmetatable({}, { __index = MountedPlayerAnimation })
	self.z_index = z_index.LEVEL
	self.player_animation = player_animation
	self.dino_animation = dino_animation
	self.player = player
	self.draw_position = player:get_draw_position()
	return self
end

function MountedPlayerAnimation:get_position(): Point
    return self.player.position
end

function MountedPlayerAnimation:hitbox(): Rectangle
    return self.player:hitbox()
end

local DINO_SLIDE_CHARACTER_ADJUST = {
	up = vectors.new(7, 0),
	down = vectors.new(-7, 0),
	right = vectors.new(9, 0),
	left = vectors.new(-9, 0)
}
local DINO_STUN_CRY_TEXT_POSITION = {
	up = vectors.new(8, -4),
	down = vectors.new(8, 18),
	right = vectors.new(18, 6),
	left = vectors.new(-4, 6)
}
local DINO_SONIC_BLAST_POSITION = {
	up = vectors.new(8, -4),
	down = vectors.new(8, 12),
	right = vectors.new(14, 6),
	left = vectors.new(0, 6)
}
local DINO_AFTERIMGE_SHIFT = {
	up = vectors.new(0, 1),
	down = vectors.new(0, -1),
	right = vectors.new(-1, 0),
	left = vectors.new(1, 0)
}
local STUN_CRY_SHAKE_PERIOD_BY_LEVEL = {
	[1] = 0.05,
	[2] = 0.10,
	[3] = 0.20,
}
local STUN_CRY_SHAKE_AXIS = {
	up = vectors.new(0, 1),
	down = vectors.new(0, -1),
	right = vectors.new(1, 0),
	left = vectors.new(-1, 0)
}
local STUN_CRY_REACH_BY_LEVEL = {
	[1] = 1.0,
	[2] = 1.75,
	[3] = 2.5
}


local function stun_cry_displacement(player: Player): Vector
	if not player:is_stun_crying() then
		return vectors.new(0, 0)
	end

	local shake_period = STUN_CRY_SHAKE_PERIOD_BY_LEVEL[player.dino.level]
	if (player.roar_for % shake_period) > shake_period / 2 then
		return STUN_CRY_SHAKE_AXIS[player.direction]
	else
		return vectors.new(0, 0)
	end
end

local function get_image_pos_in_front_of_player(player: Player, image: Image, x_scaling: number, y_scaling: number): Point
	local pos = player.position
	if player.direction == "left" or player.direction == "right" then
		pos = pos:move(vectors.new(0, -image:getHeight()*y_scaling / 2))
	else
		pos = pos:move(vectors.new(-image:getWidth()*x_scaling / 2, 0))
	end

	if player.direction == "left" then
		pos = pos:move(vectors.new(-image:getWidth()*x_scaling, 0))
	elseif player.direction == "up" then
		pos = pos:move(vectors.new(0, -image:getHeight()*y_scaling))
	end

	return pos
end


local function draw_sonic_blasts(player: Player)
	if not player:is_sonic_blasting() then
		return
	end

	local function get_text_position(scaling: number, wave_image: Image): Point
		local pos = get_image_pos_in_front_of_player(player, wave_image, scaling, scaling)
		return pos:move(DINO_SONIC_BLAST_POSITION[player.direction])
	end

	local reach = (player.dino.level + 1) * grid.TILE_SIZE
	for _, sonic_wave in ipairs(player.sonic_waves) do
		local sonic_wave_speed = reach / sonic_wave.live_for
		local sonic_image = sonic_wave_images[player.direction][sonic_wave.color]
		local scale = sonic_wave.duration / sonic_wave.live_for
		local traveled = sonic_wave.duration * sonic_wave_speed
		local pos = get_text_position(scale, sonic_image)
		pos = pos:move(vectors.from_direction(player.direction):scale(traveled))
		lutro.graphics.draw(sonic_image, pos.x, pos.y, 0, scale, scale)
	end
end


local function draw_stun_cry_text(player: Player)
	if not player:is_stun_crying() then
		return
	end

	local since_roar_buildup = player:have_roared_since_buildup_for()
	
	local function get_text_x_y_scaling(): (number, number)
		local text_len_max_scale = STUN_CRY_REACH_BY_LEVEL[player.dino.level]
		local text_length_scale = math.min(since_roar_buildup*3, text_len_max_scale)
		local text_height_scale = math.min(since_roar_buildup*4, 1.0)
		
		if player.direction == "down" or player.direction == "up" then
			return text_height_scale, text_length_scale
		else
			return text_length_scale, text_height_scale
		end
	end

	local function get_text_position(text: Image): Point
		local x_scale, y_scale = get_text_x_y_scaling()
		local pos = get_image_pos_in_front_of_player(player, text, x_scale, y_scale)
		return pos:move(DINO_STUN_CRY_TEXT_POSITION[player.direction])
	end
	
	local text = stun_cry_text_images[player.direction][player.dino.level]
	local draw_pos = get_text_position(text)
	local x_scale, y_scale = get_text_x_y_scaling()
	lutro.graphics.draw(text, draw_pos.x, draw_pos.y, 0, x_scale, y_scale)
end

function MountedPlayerAnimation:draw()
	if not self.player:is_alive() then
		return
	end

	local function draw(animation: Animation, pos: Point)
		local draw_pos = block_to_anim_draw_pos(animation, pos)
		animation:draw(draw_pos.x, draw_pos.y)
	end

	local function dino_position(): Point
		if self.player.action == "jump" then
			return self.player:get_jump_position()
		elseif self.player.action == "roar" then
			return self.player.dino.position:move(stun_cry_displacement(self.player))
		else
			return self.player.dino.position
		end
	end

	if self.player.direction == "up" then
		-- Stun cry text in upward direction should be behind player and dino. Note that
		-- every entity upwards will have lower y-coord so it will be above them
		draw_stun_cry_text(self.player)
		draw_sonic_blasts(self.player)
	end

	if self.player.action == "dash" and self.player.dino and self.player.dino.level == 3 then
		local shift_vector = DINO_AFTERIMGE_SHIFT[self.player.direction]:scale(self.player.after_image_shift)
		-- Draw after image shifted behind when dashing
		draw(self.dino_animation, dino_position():move(shift_vector))	
	end

	if self.player.action == "slide" and self.player.dino and self.player.dino.level == 2  then
		local character_pos = self.draw_position:move(DINO_SLIDE_CHARACTER_ADJUST[self.player.direction])
		if self.player.direction == "right" or self.player.direction == "left" then
			-- Need to draw dino in front of player sliding left or right with level 2 dino
			draw(self.player_animation, character_pos)
			draw(self.dino_animation, dino_position())
		else
			-- For up and down the player is on front
			draw(self.dino_animation, dino_position())
			draw(self.player_animation, character_pos)
		end
	elseif self.player.direction == "down" then
		-- Need to draw dino in front of player walking towards screen
		draw(self.player_animation, self.draw_position)
		draw(self.dino_animation, dino_position())
	else
		-- And player in front of dino in all other cases
		draw(self.dino_animation, dino_position())
		draw(self.player_animation, self.draw_position)
	end
end

local record PlayerAnimations
    regular: {integer: {PlayerState: {Action: {Direction: Animation}}}}
    invulnerable: {integer: {PlayerState: {Action: {Direction: Animation}}}}
    players: {Player}
	dinos: AnimatedDinos
end

function PlayerAnimations:add_new(player: Player)
    self.regular[player.id] = character_animation(player.sprite, false)
    self.invulnerable[player.id] = character_animation(player.sprite, true)
    table.insert(self.players, player)
end

local function character_sprite_for_action(character_asset: CharacterName, state: PlayerState, action: Action): {Direction: Image}
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
		elseif action == "jump" or action == "dash" or action == "roar" then
			-- Same sprite for jump as walk/idle, is always on mount when this happen
			return "walk"
		else
			return action
		end
	end

	local base_path = "assets/" .. character_asset .. "/" .. state .. "/" .. action_resolved()
	return {
		up = lutro.graphics.newImage(base_path .. "_up.png"),
		down = lutro.graphics.newImage(base_path .. "_down.png"),
		right = lutro.graphics.newImage(base_path .. "_right.png"),
		left = lutro.graphics.newImage(base_path .. "_left.png"),
	}
end

local function character_sprite_for_dying(character_asset: CharacterName): {Direction: Image}
	local asset_file = "assets/" .. character_asset .. "/foot/dying.png"
	local image = lutro.graphics.newImage(asset_file)
	return {
		up = image,
		down = image,
		right = image,
		left = image,
	}
end

local function character_sprite_for_stunned(character_asset: CharacterName, state: PlayerState): {Direction: Image}
	if state == "mounted" then
		-- Stunned when mounted has same sprite as for walking
		return character_sprite_for_action(character_asset, state, "walk")
	end

	local asset_file = "assets/" .. character_asset .. "/" .. state .. "/stunned.png"
	local image = lutro.graphics.newImage(asset_file)
	return {
		up = image,
		down = image,
		right = image,
		left = image,
	}
end

local function character_sprites_for_state(character_asset: CharacterName, state: PlayerState): {Action: {Direction: Image}}
	local sprite_images <total>: {Action: {Direction: Image}} = {
		walk = character_sprite_for_action(character_asset, state, "walk"),
		idle = character_sprite_for_action(character_asset, state, "idle"),
		jump_on = character_sprite_for_action(character_asset, state, "jump_on"),
		jump_off = character_sprite_for_action(character_asset, state, "jump_off"),
		jump = character_sprite_for_action(character_asset, state, "jump"),
		dash = character_sprite_for_action(character_asset, state, "dash"),
		dying = character_sprite_for_dying(character_asset),
		stunned = character_sprite_for_stunned(character_asset, state),
		crashed = character_sprite_for_stunned(character_asset, state),
		slide = character_sprite_for_stunned(character_asset, state),
		roar = character_sprite_for_stunned(character_asset, state)
	}
	return sprite_images
end

local function character_sprites(character_asset: CharacterName): SpriteImages
	local sprites_images <total>: SpriteImages = {
		foot = character_sprites_for_state(character_asset, "foot"),
		mounted = character_sprites_for_state(character_asset, "mounted"),
	}
	return sprites_images
end

local player_animations = {PlayerAnimations = PlayerAnimations}

function player_animations.load_assets()
	jump_shadow_image = lutro.graphics.newImage("assets/items/shadow.png")
	for _, sprite_name in ipairs(characters.get_names()) do
		sprites[sprite_name] = character_sprites(sprite_name)
		sprites_invulnerable[sprite_name] = character_sprites(sprite_name)
	end

	for _, by_state in pairs(sprites_invulnerable) do
		for _, by_action in pairs(by_state) do
			for _, by_direction in pairs(by_action) do
				for _, sprite_image in pairs(by_direction) do
					images.make_lighter(sprite_image, 0.6)
				end
			end
		end
	end

	local function get_stun_cry_text_for_dir(dir: string): {integer: Image}
		local result: {integer: Image} = {}
		for level=1, 3 do
			local asset = "assets/tirras/level_" .. level .. "/stun_cry_text_" .. dir .. ".png"
			result[level] = lutro.graphics.newImage(asset)
		end

		return result
	end

	local vertical_image = get_stun_cry_text_for_dir("vertical")
	local horizontal_image = get_stun_cry_text_for_dir("horizontal")
	-- Right and up images are 
	stun_cry_text_images = {
		up = vertical_image,
		down = vertical_image,
		right = horizontal_image,
		left = horizontal_image
	}

	local function get_sonic_blast_for_dir(dir: string): {SonicWaveColor: Image}
		local sonic_images<total>: {SonicWaveColor: Image} = {
			purple = lutro.graphics.newImage("assets/tirras/sonic-" .. dir .. "-purple.png"),
			white = lutro.graphics.newImage("assets/tirras/sonic-" .. dir .. "-white.png"),
			yellow = lutro.graphics.newImage("assets/tirras/sonic-" .. dir .. "-yellow.png")
		}
		return sonic_images
	end

	local vertical_sonic_image = get_sonic_blast_for_dir("vertical")
	local horizontal_sonic_image = get_sonic_blast_for_dir("horizontal")
	sonic_wave_images = {
		up = vertical_sonic_image,
		down = vertical_sonic_image,
		right = horizontal_sonic_image,
		left = horizontal_sonic_image
	}
end

function player_animations.new(entities: {Player}): PlayerAnimations
    local self: PlayerAnimations = setmetatable({}, { __index = PlayerAnimations })
    self.regular = {}
    self.invulnerable = {}
    self.players = {}
	self.dinos = dino_animations.new()

    for _, player in ipairs(entities) do
		self:add_new(player)
	end
    return self
end

function PlayerAnimations:update(dt: number)
	self.dinos:update(dt)
    for _, player in ipairs(self.players) do
		-- Update animations regardless if alive or not
		self.regular[player.id][player.state][player.action][player.direction]:update(dt)
		self.invulnerable[player.id][player.state][player.action][player.direction]:update(dt)
	end
end

local SLIDE_WIHT_DINO_DIR_MAP: {Direction: Direction} = {
	up = "left",
	down = "right",
	left = "down",
	right = "down"
}

function PlayerAnimations:_get_for(player: Player): Animation
	local function get_direction(): Direction
		if player.dino and player.dino.action == "slide" and player.dino.level == 2 then
			-- For level 2 dino sliding the character riding it should turn depending
			-- on the direction sliding for it to look like they bracing sliding to a stop:
			return SLIDE_WIHT_DINO_DIR_MAP[player.direction]
		else
			return player.direction
		end
	end

	local resolved_dir = get_direction()
    if player:is_invulnerable() and player.invulnerable_for % 0.3 < 0.15 then
        return self.invulnerable[player.id][player.state][player.action][resolved_dir]
    else
        local animation = self.regular[player.id][player.state][player.action][resolved_dir]
        if player.action == "dying" and animation.loops > 0 then
            -- If dying and the animation have played one loop then don't draw anything:
            return nil
        else
            return animation
        end
    end
end

function PlayerAnimations:get_all(): {Entity}
	local dinos_drawn_with_player: {Dino} = {}
	local entities_to_draw: {Entity} = {}
	for _, player in ipairs(self.players) do
		local player_animation = self:_get_for(player)
		if player:is_riding_dino() then
			local dino_anim = self.dinos:get_from(player.dino)
			table.insert(dinos_drawn_with_player, player.dino)
			table.insert(entities_to_draw, MountedPlayerAnimation.new(player_animation, dino_anim, player))
		elseif player_animation then
			table.insert(entities_to_draw, PlayerAnimation.new(player_animation, player))
		end
	end

	for dino, animation in pairs(self.dinos:get_all_except(dinos_drawn_with_player)) do
		table.insert(entities_to_draw, MountAnimation.new(animation, dino))
	end

	return entities_to_draw
end

function PlayerAnimations:_draw_players_shadow(filter: function(Player): boolean)
	for _, player in ipairs(itertools.filter(self.players, filter)) do
		lutro.graphics.draw(jump_shadow_image, player.position.x - 1, player.position.y - 10)
	end
end

function PlayerAnimations:draw_lateral_jump_shadows()
	local function jumps_lateral(player: Player): boolean
		return player.action == "jump" and player.jump_trajectory.lateral_velocity:length() > 0
	end

	self:_draw_players_shadow(jumps_lateral)
end

function PlayerAnimations:draw_vertical_jump_shadows()
	local function jumps_vertically(player: Player): boolean
		return player.action == "jump" and player.jump_trajectory.lateral_velocity:length() == 0
	end

	self:_draw_players_shadow(jumps_vertically)
end

function PlayerAnimations:draw_stun_cry_texts_not_up()
	for _, player in ipairs(self.players) do
		if player.direction ~= "up" then
			draw_stun_cry_text(player)
			draw_sonic_blasts(player)
		end
	end
end

return player_animations
