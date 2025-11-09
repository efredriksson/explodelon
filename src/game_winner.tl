local animations = require("animations")
local audio = require("audio")
local characters = require("characters")
local const = require("const")
local points = require("geometry.points")
local vectors = require("geometry.vectors")
local scenes = require("scenes")


local record GameWinner is Scene
	name: CharacterName
	trophy: Animation
	trophy_position: Point
	character_position: Point
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

local game_winner = {}

function game_winner.load_assets()
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

function game_winner.new(name: CharacterName): GameWinner
    local self: GameWinner = setmetatable({}, { __index = GameWinner })
	self.name = name
	self.trophy = animations.new_with_frames(trophy_image, {2, 0.1, 0.1, 1, 0.1})
	self.trophy_position = points.new(
		(const.MAP_WIDTH - self.trophy.width) / 2,
		(const.MAP_HEIGHT - self.trophy.height) / 2
	)
	self.character_position = points.new(
		(const.MAP_WIDTH - jump_animations[name]:getWidth()) / 2,
		const.MAP_HEIGHT
	)
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

function GameWinner:_get_trophy_height_diff(): number
	local period = 3
	local amplitude = 8
	return math.sin(self.waited_for * period) * amplitude
end

function GameWinner:update(dt: number)
	self.waited_for = self.waited_for + dt

	local gravity = vectors.new(0, 10):scale(dt)
	self.character_jump_velocity = self.character_jump_velocity:plus(gravity)
	self.character_position = self.character_position:move(self.character_jump_velocity:scale(dt))

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

function GameWinner:draw()
	lutro.graphics.setColor(72, 72, 72)
	lutro.graphics.rectangle("fill", 0, 0, const.MAP_WIDTH, const.MAP_HEIGHT)

	lutro.graphics.draw(jump_animations[self.name], self.character_position.x, self.character_position.y)
	local pos = self.trophy_position:move(vectors.new(0, self:_get_trophy_height_diff()))
	self.trophy:draw(pos.x, pos.y)
	for spark_dp, spark_anim in pairs(self.sparks) do
		local spark_pos = pos:move(spark_dp)
		spark_anim:draw(spark_pos.x, spark_pos.y)
	end
end

return game_winner
