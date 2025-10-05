require("animation")
require("dinos")

local IMAGE_CACHE: {string: Image} = {}

local function get_cached_lutro_image(asset_file: string): Image
	local cached_image = IMAGE_CACHE[asset_file]
	if not cached_image then
		IMAGE_CACHE[asset_file] = lutro.graphics.newImage(asset_file)
	end

	return IMAGE_CACHE[asset_file]
end

local function dino_animation(asset_file: string): Animation
	return Animation.new(get_cached_lutro_image(asset_file), 34, 34, 3, 18)
end

local function dino_animation_for_level(action: DinoAction, direction: Direction): {integer: Animation}
	local png_name = action .. "_" .. direction
	return {
		[1] = dino_animation("assets/tirras/level_1/" .. png_name .. ".png"),
		[2] = dino_animation("assets/tirras/level_2/" .. png_name .. ".png"),
		[3] = dino_animation("assets/tirras/level_3/" .. png_name .. ".png"),
	}
end

local function dino_animation_for_dir(direction: Direction): {DinoAction: {integer: Animation}}
	return {
		["walk"] = dino_animation_for_level("walk", direction),
		["idle"] = dino_animation_for_level("idle", direction),
	}
end

global record AnimatedDino
    dino: Dino
	animations: {Direction: {DinoAction: {integer: Animation}}}
end

function AnimatedDino.new(dino: Dino): AnimatedDino
   	local self: AnimatedDino = setmetatable({}, { __index = AnimatedDino })
   	self.dino = dino
   	self.animations = {
		["up"] = dino_animation_for_dir("up"),
		["down"] = dino_animation_for_dir("down"),
		["right"] = dino_animation_for_dir("right"),
		["left"] = dino_animation_for_dir("left"),
	}
   	return self
end

function AnimatedDino:get_animation(): Animation
	return self.animations[self.dino.direction][self.dino.action][self.dino.level]
end

function AnimatedDino:update(dt: number)
	self:get_animation():update(dt)
end

global record AnimatedDinos
    existing: {AnimatedDino}
end

function AnimatedDinos.new(): AnimatedDinos
   local self: AnimatedDinos = setmetatable({}, { __index = AnimatedDinos })
   self.existing = {}
   return self
end

function AnimatedDinos:update(dt: number)
	for _, animated in ipairs(self.existing) do
		animated:update(dt)

		-- TODO: Remove dinos that are dead
	end
end

function AnimatedDinos:add(dino: Dino)
	table.insert(self.existing, AnimatedDino.new(dino))
end

function AnimatedDinos:get_from(dino: Dino): Animation
	for _, animated in ipairs(self.existing) do
		if animated.dino == dino then
			return animated:get_animation()
		end
	end
end
