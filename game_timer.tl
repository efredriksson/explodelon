require("geometry")
require("fonts")

local TIMER_POS = Point.new(18, 8)

global record GameTimer
   time_left: number
end

function GameTimer.new(time_left: number): GameTimer
   local self: GameTimer = setmetatable({}, { __index = GameTimer })
   self.time_left = time_left
   return self
end


function GameTimer:load_assets()
	global clock_font = get_shaded_number_font()
end

function GameTimer:decrement(dt: number): boolean
	self.time_left = self.time_left - dt
	return self.time_left < 0
end

local function time_to_clock_text(time_in_sec: number): string
	time_in_sec = math.max(time_in_sec, 0)
	local minutes = math.floor(time_in_sec / 60)
	local seconds = math.floor(time_in_sec - minutes * 60)
	local microsec = math.floor((time_in_sec - seconds) * 100)
	local first_num = minutes
	local second_num = seconds
	local delimiter = ":"

	if minutes == 0 then
		first_num = seconds
		second_num = microsec
		delimiter = "\""
	end

	local function left_pad(n: integer, pad_char: string): string
		if n < 10 then return pad_char .. n else return tostring(n) end
	end

	return left_pad(first_num, " ") .. delimiter .. left_pad(second_num, "0")
end

function GameTimer:draw()
	local clock_text = time_to_clock_text(self.time_left)
	clock_font:draw(clock_text, TIMER_POS)
end

function GameTimer:finished(): boolean
	return self.time_left <= 0.0
end

function GameTimer:sudden_death(): boolean
	return self.time_left <= 60.0
end
