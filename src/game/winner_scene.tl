local animations = require("engine.animations")
local audio = require("engine.audio")
local characters = require("characters")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local scenes = require("engine.scenes")
local screen = require("screen")

local type Animation = animations.Animation
local type CharacterName = characters.CharacterName
local type Scene = scenes.Scene
local type Vector = vectors.Vector
local type Point = points.Point

local record GameWinnerScene is Scene
	names: {CharacterName}
	trophy: Animation
	trophy_position: Point
	character_positions: {CharacterName: Point}
	character_jump_velocity: Vector
	sparks: {Vector: Animation}
    have_played_sound: boolean
	waited_for: number
end

local trophy_image: Image
local spark_1_image: Image
local spark_2_image: Image
local jump_animations: {CharacterName: Image}
local music: Source

local winner_scene = {}

function winner_scene.load_assets()
	trophy_image = lutro.graphics.newImage("assets/trophy.png")
	spark_1_image = lutro.graphics.newImage("assets/spark-1.png")
	spark_2_image = lutro.graphics.newImage("assets/spark-2.png")
	jump_animations = {}
	for _, character_name in ipairs(characters.get_names()) do
		jump_animations[character_name] = lutro.graphics.newImage(
			"assets/" .. character_name .. "/foot/jump_down.png"
		)
	end
	music = audio.new_source("assets/music/winner.ogg", "static")
	music:setVolume(0.75)
end

function winner_scene.new(names: {CharacterName}): GameWinnerScene
    local self: GameWinnerScene = setmetatable({}, { __index = GameWinnerScene })
	self.names = names
	self.trophy = animations.new_with_frames(trophy_image, {2, 0.1, 0.1, 1, 0.1})
	self.trophy_position = points.new(
		(screen.WIDTH - self.trophy.width) / 2,
		(screen.HEIGHT - self.trophy.height) / 2
	)
	self.character_positions = {}
	for _, name in ipairs(names) do
		self.character_positions[name] = points.new(
			(screen.WIDTH - jump_animations[name]:getWidth()) / 2,
			screen.HEIGHT
		)
	end
	self.character_jump_velocity = vectors.new(0, -47)
	self.have_played_sound = false
	self.waited_for = 0.0

	self.sparks = {}
	local function add_random_spark(spark_image: Image, start_time: number): Vector, Animation
		local spark = animations.new_with_frames(spark_image, {2.7, 0.2, 0.2, 0.2})
		spark.timer = (2.7 - start_time) + lutro.math.random() * 0.1
		local spark_dp = vectors.new(lutro.math.random(-1, 17), lutro.math.random(-1, 23))
		self.sparks[spark_dp] = spark
	end
	
	for _=1, 4 do
		add_random_spark(spark_1_image, 2.15)
		add_random_spark(spark_2_image, 3.25)
	end

    return self
end

function GameWinnerScene:_get_trophy_height_diff(): number
	local period = 3
	local amplitude = 8
	return math.sin(self.waited_for * period) * amplitude
end

function GameWinnerScene:update(dt: number)
	self.waited_for = self.waited_for + dt

	local gravity = vectors.new(0, 10):scale(dt)
	self.character_jump_velocity = self.character_jump_velocity:plus(gravity)
	for _, name in ipairs(self.names) do
		self.character_positions[name] = self.character_positions[name]:move(self.character_jump_velocity:scale(dt))
	end

	self.trophy:update(dt)
	for _, spark in pairs(self.sparks) do
		spark:update(dt)
	end

	if not music:isPlaying() then
		music:play()
	end

	if self.character_jump_velocity.y > -5 then
		music:stop()
		scenes.return_to_start()
	end
end

function GameWinnerScene:draw()
	lutro.graphics.setColor(72, 72, 72)
	lutro.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

	for _, name in ipairs(self.names) do
		lutro.graphics.draw(jump_animations[name], self.character_positions[name].x, self.character_positions[name].y)
	end
	local pos = self.trophy_position:move(vectors.new(0, self:_get_trophy_height_diff()))
	self.trophy:draw(pos.x, pos.y)
	for spark_dp, spark_anim in pairs(self.sparks) do
		local spark_pos = pos:move(spark_dp)
		spark_anim:draw(spark_pos.x, spark_pos.y)
	end
end

return winner_scene
