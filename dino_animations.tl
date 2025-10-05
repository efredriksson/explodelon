require("animation")
require("dinos")

local function dino_animation(asset_file: string): Animation
	return Animation.new(lutro.graphics.newImage(asset_file), 34, 34, 3, 18)
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


global function load_dino_assets()
	global dino_animations: {Direction: {DinoAction: {integer: Animation}}} =
	{
		["up"] = dino_animation_for_dir("up"),
		["down"] = dino_animation_for_dir("down"),
		["right"] = dino_animation_for_dir("right"),
		["left"] = dino_animation_for_dir("left"),
	}
end

--- Temporary, refactor away
global function get_dino_animation(dino: Dino): Animation
    return dino_animations[dino.direction][dino.action][dino.level]
end
