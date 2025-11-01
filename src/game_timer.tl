local clock_text = require("clock_text")
local fonts = require("fonts")
local points = require("geometry.points")
local settings = require("settings")


local TIMER_POS = points.new(18, 8)

global record GameTimer
   time_left: number
end

local clock_font: ShadedFont
local game_timer = {}

function game_timer.new(): GameTimer
   local self: GameTimer = setmetatable({}, { __index = GameTimer })
   self.time_left = settings.battle_time
   return self
end


function GameTimer.load_assets()
	clock_font = fonts.new_shaded_numbers()
end

function GameTimer:update(dt: number)
	self.time_left = self.time_left - dt
end

function GameTimer:out_of_time(): boolean
	return self.time_left < 0
end

function GameTimer:draw()
	local text = clock_text.from_time(self.time_left)
	clock_font:draw(text, TIMER_POS)
end

function GameTimer:finished(): boolean
	return self.time_left <= 0.0
end

function GameTimer:sudden_death(): boolean
	return self.time_left <= settings.sudden_death_time
end

return game_timer
