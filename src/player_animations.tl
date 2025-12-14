require("players")
local animations = require("animations")
local const = require("const")
local dino_animations = require("dino_animations")
local points = require("geometry.points")

local jump_shadow_image: Image

--- Scale 0-1 represent how far from current to max to increase color component 
local function increase_color(color: number, scale: number): number
	return color + scale * (255 - color)
end

local function make_lighter(image: Image)
	local image_data = image:getData()
	local scale = 0.6
	-- Using C index in getPixel API for some reason...
	for i = 0, image:getWidth() - 1 do
		for j = 0, image:getHeight() - 1 do
			local r, g, b, alpha = image_data:getPixel(i, j)
			if alpha ~= 0 then
				r = increase_color(r, scale)
				g = increase_color(g, scale)
				b = increase_color(b, scale)
				image_data:setPixel(i, j, r, g, b, alpha)
			end
		end
	end
end

local function get_animation(asset_file: string, invulnerable: boolean): Animation
	local image = lutro.graphics.newImage(asset_file)
	if invulnerable then
		make_lighter(image)
	end

	return animations.new(image, 18, 34, 3, 18)
end

local function character_animation_for_action(character_asset: string, state: PlayerState, action: Action, invulnerable: boolean): {Direction: Animation}
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
		elseif action == "jump" then
			-- Same sprite for jump as walk/idle, is always on mount when this happen
			return "walk"
		else
			return action
		end
	end

	local base_path = "assets/" .. character_asset .. "/" .. state .. "/" .. action_resolved()
	return {
		up = get_animation(base_path .. "_up.png", invulnerable),
		down = get_animation(base_path .. "_down.png", invulnerable),
		right = get_animation(base_path .. "_right.png", invulnerable),
		left = get_animation(base_path .. "_left.png", invulnerable),
	}
end

local function character_animation_for_dying(character_asset: string): {Direction: Animation}
	local asset_file = "assets/" .. character_asset .. "/foot/dying.png"
	local image = lutro.graphics.newImage(asset_file)
	local animation = animations.new(image, 18, 34, 1, 8)
	return {
		up = animation,
		down = animation,
		right = animation,
		left = animation,
	}
end

local function character_animation_for_stunned(character_asset: string, state: PlayerState): {Direction: Animation}
	if state == "mounted" then
		-- Stunned when mounted has same sprite as for walking
		return character_animation_for_action(character_asset, state, "walk", false)
	end

	local asset_file = "assets/" .. character_asset .. "/" .. state .. "/stunned.png"
	local image = lutro.graphics.newImage(asset_file)
	local animation = animations.new(image, 18, 34, 1, 8)
	return {
		up = animation,
		down = animation,
		right = animation,
		left = animation,
	}
end

local function character_animations_for_state(character_asset: string, state: PlayerState, invulnerable: boolean): {Action: {Direction: Animation}}
	return {
		walk = character_animation_for_action(character_asset, state, "walk", invulnerable),
		idle = character_animation_for_action(character_asset, state, "idle", invulnerable),
		jump_on = character_animation_for_action(character_asset, state, "jump_on", invulnerable),
		jump_off = character_animation_for_action(character_asset, state, "jump_off", invulnerable),
		jump = character_animation_for_action(character_asset, state, "jump", invulnerable),
		dying = character_animation_for_dying(character_asset),
		stunned = character_animation_for_stunned(character_asset, state)
	}
end

local function character_animation(character_asset: string, invulnerable: boolean): {PlayerState: {Action: {Direction: Animation}}}
	return {
		foot = character_animations_for_state(character_asset, "foot", invulnerable),
		mounted = character_animations_for_state(character_asset, "mounted", invulnerable),
	}
end

local record PlayerAnimation is Entity
	player: Player
	draw_position: Point
	animation: Animation
end

function PlayerAnimation.new(animation: Animation, player: Player): PlayerAnimation
	local self: PlayerAnimation = setmetatable({}, { __index = PlayerAnimation })
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
		pos.x + (const.BLOCK_SIZE - animation.width) / 2,
		pos.y - animation.height + const.BLOCK_SIZE + 1)
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
		else
			return self.player.dino.position
		end
	end

	if self.player.direction == "down" then
		-- Need to draw dino in front of player walking towards screen
		draw(self.player_animation, self.draw_position)
		draw(self.dino_animation, dino_position())
	else
		-- And player in front of dino in all other cases
		draw(self.dino_animation, dino_position())
		draw(self.player_animation, self.draw_position)
	end
end

global record PlayerAnimations
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

local player_animations = {}

function player_animations.load_assets()
	jump_shadow_image = lutro.graphics.newImage("assets/items/shadow.png")
end

function player_animations.new(players: {Player}): PlayerAnimations
    local self: PlayerAnimations = setmetatable({}, { __index = PlayerAnimations })
    self.regular = {}
    self.invulnerable = {}
    self.players = {}
	self.dinos = dino_animations.new()

    for _, player in ipairs(players) do
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

function PlayerAnimations:_get_for(player: Player): Animation
    if player:is_invulnerable() and player.invulnerable_for % 0.3 < 0.15 then
        return self.invulnerable[player.id][player.state][player.action][player.direction]
    else
        local animation = self.regular[player.id][player.state][player.action][player.direction]
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
			local dion_anim = self.dinos:get_from(player.dino)
			table.insert(dinos_drawn_with_player, player.dino)
			table.insert(entities_to_draw, MountedPlayerAnimation.new(player_animation, dion_anim, player))
		elseif player_animation then
			table.insert(entities_to_draw, PlayerAnimation.new(player_animation, player))
		end
	end

	for dino, animation in pairs(self.dinos:get_all_except(dinos_drawn_with_player)) do
		table.insert(entities_to_draw, MountAnimation.new(animation, dino))
	end

	return entities_to_draw
end

function PlayerAnimations:draw_shadows()
	for _, player in ipairs(self.players) do
		if player.action == "jump" then
			lutro.graphics.draw(jump_shadow_image, player.position.x - 1, player.position.y - 10)
		end
	end
end

return player_animations
