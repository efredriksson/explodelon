local animations = require("engine.animations")
local audio = require("engine.audio")
local points = require("engine.geometry.points")

local type Animation = animations.Animation

local TIMER_POS = points.new(14, 1)
local READY_AT_TIME = 3
local SHOW_TIME_MARGIN = 1

local record GameCountdown
	animation: Animation
    have_played_sound: boolean
	waited_for: number 
end

local ready_set_go_image: Image
local ready_set_go_frame_image: Image
local ready_set_go_sound: Source
local start_jingle: Source

local countdown = {GameCountdown = GameCountdown}

function countdown.load_assets()
	ready_set_go_image = lutro.graphics.newImage("assets/ready_set_go.png")
	ready_set_go_frame_image = lutro.graphics.newImage("assets/ready_set_go_frame.png")
	ready_set_go_sound = audio.new_source("assets/ready_set_go.wav", "static")
	start_jingle = audio.new_source("assets/battle-start.ogg", "static")
	start_jingle:setVolume(0.35)
end

function countdown.new(): GameCountdown
    local self: GameCountdown = setmetatable({}, { __index = GameCountdown })
	local image_width = 52
	self.animation = animations.new(ready_set_go_image, image_width, 1)
	self.have_played_sound = false
	self.waited_for = 0.0
	ready_set_go_sound:stop()
	start_jingle:stop()
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
		start_jingle:play()
		ready_set_go_sound:play()
		self.have_played_sound = true
	end
end

function GameCountdown:draw()
	if self.waited_for < READY_AT_TIME + SHOW_TIME_MARGIN then
		local position = TIMER_POS
		lutro.graphics.draw(ready_set_go_frame_image, position.x, position.y)
		self.animation:draw(position.x, position.y)
	end
end

return countdown
