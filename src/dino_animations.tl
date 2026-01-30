local animations = require("engine.animations")
local dinos = require("dinos")
local images = require("engine.images")
local vectors = require("engine.geometry.vectors")
local settings = require("settings")

local type Animation = animations.Animation
local type Color = images.Color
local type DinoAction = dinos.DinoAction
local type Dino = dinos.Dino
local type DinoColor = settings.DinoColor
local type Direction = vectors.Direction
local type DinoImageByActionAndLevel = {DinoAction: {integer: Image}}
local type DinoImages = {DinoColor: {Direction: DinoImageByActionAndLevel}}
local type DinoAnimations = {Direction: {DinoAction: {integer: Animation}}}

local dino_images: DinoImages
local pixel_maps <total>: {DinoColor: {Color: Color}} = {
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

local function dino_iamge(level: integer, action: DinoAction, direction: Direction, color: DinoColor): Image
	local png_name = action .. "_" .. direction
	if action == "crashed" then
		level = 1 -- Only possible to crash with level 1 dino
	end
	if action == "slide" and level == 1 then
		level = 2 -- Not possible to slide with level 1 dino
	end
	
	if action == "dying" or action == "stunned" then
		png_name = action
	end

	local image = lutro.graphics.newImage("assets/tirras/level_" .. level .. "/" .. png_name .. ".png")
	images.change_colors(image, pixel_maps[color])
	return image
end


local function dino_images_for_level(action: DinoAction, direction: Direction, color: DinoColor): {integer: Image}
	return {
		[1] = dino_iamge(1, action, direction, color),
		[2] = dino_iamge(2, action, direction, color),
		[3] = dino_iamge(3, action, direction, color),
	}
end

local function dino_images_for_dir(direction: Direction, color: DinoColor): DinoImageByActionAndLevel
	local dino_animations <total>: DinoImageByActionAndLevel = {
		walk = dino_images_for_level("walk", direction, color),
		idle = dino_images_for_level("idle", direction, color),
		dying = dino_images_for_level("dying", direction, color),
		stunned = dino_images_for_level("stunned", direction, color),
		crashed = dino_images_for_level("crashed", direction, color),
		slide = dino_images_for_level("slide", direction, color),
		jump = dino_images_for_level("jump", direction, color),
		dash = dino_images_for_level("dash", direction, color)
	}
	return dino_animations
end

local function dino_images_for_color(color: DinoColor): {Direction : {DinoAction : {integer : Image}}}
	return {
		up = dino_images_for_dir("up", color),
		down = dino_images_for_dir("down", color),
		right = dino_images_for_dir("right", color),
		left = dino_images_for_dir("left", color),
	}
end

local function get_dino_images(): DinoImages
	local dino_images_total <total>: DinoImages = {
		blue = dino_images_for_color("blue"),
		pink = dino_images_for_color("pink"),
		purple = dino_images_for_color("purple"),
		green = dino_images_for_color("green"),
		yellow = dino_images_for_color("yellow"),
	}
	return dino_images_total
end

local record AnimatedDino
    dino: Dino
	finished: boolean
	previous_action: DinoAction
	animations: DinoAnimations
end

local function get_dash_fames(level: integer): {number}
	if level == 3 then
		return {0.1, 0.1}
	else
		return {0.1, 0.1, 0.1}
	end
end

local function new_dino_animations(color: DinoColor): DinoAnimations
	local new_animations: DinoAnimations = {}

	local function create_animations(image: Image, action: DinoAction, level: integer): Animation
		if action == "jump" then
			return animations.new_with_frames(image, {0.1, 10000})
		elseif action == "crashed" then
			return animations.new_with_frames(image, {0.2, 0.4, 0.2, 0.2, 10000})
		elseif action == "slide" then
			return animations.new_with_frames(image, {0.1, 10000})
		elseif action == "dash" then
			return animations.new_with_frames(image, get_dash_fames(level))
		else
			return animations.new(image, 34, 1 / 6)
		end
	end

	for direction, image_by_level_by_action in pairs(dino_images[color]) do
		new_animations[direction] = {}
		for action, image_by_level in pairs(image_by_level_by_action) do
			new_animations[direction][action] = {}
			for level, image in pairs(image_by_level) do
				new_animations[direction][action][level] = create_animations(image, action, level)
			end
		end
	end

	return new_animations
end

function AnimatedDino.new(dino: Dino): AnimatedDino
   	local self: AnimatedDino = setmetatable({}, { __index = AnimatedDino })
   	self.dino = dino
	self.finished = false
	self.previous_action = "idle"
   	self.animations = new_dino_animations(dino.color)
   	return self
end

function AnimatedDino:get_animation(): Animation
	return self.animations[self.dino.direction][self.dino.action][self.dino.level]
end

function AnimatedDino:update(dt: number)
	local animation = self:get_animation()

	if self.previous_action ~= self.dino.action then
		animation:reset()
	end

	animation:update(dt)
	self.previous_action = self.dino.action

	if self.dino.action == "dying" and animation.loops > 0 then
		self.finished = true
	end
end

local record AnimatedDinos
    existing: {AnimatedDino}
end

local dino_animations = {AnimatedDinos = AnimatedDinos}

function dino_animations.load_assets()
	dino_images = get_dino_images()
end

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
