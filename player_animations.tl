require("animation")
require("player")
require("dino_animations")


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

	return Animation.new(image, 18, 34, 3, 18)
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
	local animation = Animation.new(image, 18, 34, 1, 8)
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
	local animation = Animation.new(image, 18, 34, 1, 8)
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

function PlayerAnimations.new(players: {Player}): PlayerAnimations
    local self: PlayerAnimations = setmetatable({}, { __index = PlayerAnimations })
    self.regular = {}
    self.invulnerable = {}
    self.players = {}
	self.dinos = AnimatedDinos.new()

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