local animations = require("animations")
local const = require("const")
local points = require("geometry.points")
local vectors = require("geometry.vectors")

local READY_AT_TIME = 3
local START_Y_POSITION = 25

global record GameCountdown
	animation: Animation
    have_played_sound: boolean
	position: Point
	waited_for: number 
end

local ready_set_go_image: Image
local ready_set_go_sound: Source

function GameCountdown.load_assets()
	ready_set_go_image = lutro.graphics.newImage("assets/ready_set_go.png")
	ready_set_go_sound = lutro.audio.newSource("assets/ready_set_go.wav", "static")
end

local game_countdown = {}

function game_countdown.new(): GameCountdown
    local self: GameCountdown = setmetatable({}, { __index = GameCountdown })
	self.animation = animations.new(ready_set_go_image, 45, 20, 1, 1)
	self.have_played_sound = false
	self.position = points.new((const.MAP_WIDTH - 45) / 2, START_Y_POSITION)
	self.waited_for = 0.0
    return self
end

function GameCountdown:finished(): boolean
    return self.waited_for > READY_AT_TIME
end

function GameCountdown:update(dt: number)
	self.waited_for = self.waited_for + dt
	if self.animation.loops == 0 then
	    self.animation:update(dt)
	end
	if not self.have_played_sound then
		lutro.audio.play(ready_set_go_sound)
		self.have_played_sound = true
	end
	if self:finished() then
		local remove_speed = 25
		self.position = self.position:move(vectors.new(0, -remove_speed):scale(dt))
	end
end

function GameCountdown:draw()
    self.animation:draw(self.position.x, self.position.y)
end

return game_countdown
