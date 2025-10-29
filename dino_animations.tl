require("dinos")
local animations = require("animations")


local IMAGE_CACHE: {string: Image} = {}
local type Color = {number, number, number}

local function color_equal(c1: Color, c2: Color): boolean
	return c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3]
end

local pixel_maps: {DinoColor: {Color: Color}} = {
	blue = {}, -- No mapping, default dino
	pink = {
		[{176, 224, 248}] = {248, 192, 248},
		[{72, 176, 248}] = {248, 112, 192},
		[{64, 120, 216}] = {208, 80, 136},
		[{0, 56, 200}] = {168, 32, 72},
	},
	purple = {
		[{176, 224, 248}] = {216, 216, 248},
		[{72, 176, 248}] = {176, 144, 248},
		[{64, 120, 216}] = {128, 96, 176},
		[{0, 56, 200}] = {80, 64, 128},
	},
    green = {
		[{176, 224, 248}] = {112, 248, 168},
		[{72, 176, 248}] = {24, 208, 40},
		[{64, 120, 216}] = {24, 152, 24},
		[{0, 56, 200}] = {0, 104, 16},
	},
    yellow = {
		[{176, 224, 248}] = {248, 248, 200},
		[{72, 176, 248}] = {232, 232, 104},
		[{64, 120, 216}] = {224, 184, 80},
		[{0, 56, 200}] = {192, 136, 8},
	},
}

local function set_dino_colors(image: Image, color: DinoColor)
	local pixel_map = pixel_maps[color]
	local image_data = image:getData()
	for i = 0, image:getWidth() - 1 do
		for j = 0, image:getHeight() - 1 do
			local r, g, b, alpha = image_data:getPixel(i, j)
			if alpha ~= 0 then
				for from_color, to_color in pairs(pixel_map) do
					if color_equal({r, g, b}, from_color) then
						r, g, b = table.unpack(to_color)
					end
				end
				image_data:setPixel(i, j, r, g, b, alpha)
			end
		end
	end
end

local function get_cached_lutro_image(asset_file: string, color: DinoColor): Image
	local cache_key = asset_file .. "~" .. color
	local cached_image = IMAGE_CACHE[cache_key]
	if not cached_image then
		local image = lutro.graphics.newImage(asset_file)
		set_dino_colors(image, color)
		IMAGE_CACHE[cache_key] = image
	end

	return IMAGE_CACHE[cache_key]
end

local function dino_animation(asset_file: string, color: DinoColor): Animation
	return animations.new(get_cached_lutro_image(asset_file, color), 34, 34, 3, 18)
end

local function dino_animation_for_level(action: DinoAction, direction: Direction, color: DinoColor): {integer: Animation}
	local png_name = action .. "_" .. direction
	if action == "dying" or action == "stunned" then
		png_name = action
	end

	return {
		[1] = dino_animation("assets/tirras/level_1/" .. png_name .. ".png", color),
		[2] = dino_animation("assets/tirras/level_2/" .. png_name .. ".png", color),
		[3] = dino_animation("assets/tirras/level_3/" .. png_name .. ".png", color),
	}
end

local function dino_animation_for_dir(direction: Direction, color: DinoColor): {DinoAction: {integer: Animation}}
	return {
		["walk"] = dino_animation_for_level("walk", direction, color),
		["idle"] = dino_animation_for_level("idle", direction, color),
		["dying"] = dino_animation_for_level("dying", direction, color),
		["stunned"] = dino_animation_for_level("stunned", direction, color),
	}
end

global record AnimatedDino
    dino: Dino
	finished: boolean
	animations: {Direction: {DinoAction: {integer: Animation}}}
	death_animation: {integer: Animation}
end

function AnimatedDino.new(dino: Dino): AnimatedDino
   	local self: AnimatedDino = setmetatable({}, { __index = AnimatedDino })
   	self.dino = dino
	self.finished = false
   	self.animations = {
		["up"] = dino_animation_for_dir("up", dino.color),
		["down"] = dino_animation_for_dir("down", dino.color),
		["right"] = dino_animation_for_dir("right", dino.color),
		["left"] = dino_animation_for_dir("left", dino.color),
	}
	self.death_animation = dino_animation_for_level("dying", "down", dino.color)
   	return self
end

function AnimatedDino:get_animation(): Animation
	if self.dino.action == "dying" then
		return self.death_animation[self.dino.level]
	end
	return self.animations[self.dino.direction][self.dino.action][self.dino.level]
end

function AnimatedDino:update(dt: number)
	local animation = self:get_animation()
	animation:update(dt)

	if self.dino.action == "dying" and animation.loops > 0 then
		self.finished = true
	end
end

global record AnimatedDinos
    existing: {AnimatedDino}
end

local dino_animations = {}

function dino_animations.new(): AnimatedDinos
   local self: AnimatedDinos = setmetatable({}, { __index = AnimatedDinos })
   self.existing = {}
   return self
end

function AnimatedDinos:update(dt: number)
	for i, animated in ipairs(self.existing) do
		animated:update(dt)

		if animated.finished then
			table.remove(self.existing, i)
		end
	end
end

function AnimatedDinos:add_for(dino: Dino)
	if dino.level == 0 then
		return -- Dino was consumed into existing dino
	end

	table.insert(self.existing, AnimatedDino.new(dino))
end

function AnimatedDinos:get_from(dino: Dino): Animation
	for _, animated in ipairs(self.existing) do
		if animated.dino == dino then
			return animated:get_animation()
		end
	end
end

function AnimatedDinos:get_all_except(exclude: {Dino}): {Dino: Animation}
	local to_return: {Dino: Animation} = {}
	for _, animated in ipairs(self.existing) do
		local is_excluded = false
		for _, excluded_dino in ipairs(exclude) do
			if excluded_dino == animated.dino then
				is_excluded = true
			end
		end

		if not is_excluded and not animated.dino.hatching then
			to_return[animated.dino] = animated:get_animation()
		end
	end

	return to_return
end

return dino_animations
