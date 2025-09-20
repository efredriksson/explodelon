
local TIMER_X_POS = 18
local TIMER_Y_POS = 8

global record GameTimer
   time_left: number
end

function GameTimer.new(time_left: number): GameTimer
   local self: GameTimer = setmetatable({}, { __index = GameTimer })
   self.time_left = time_left
   return self
end


function GameTimer:load_assets()
	local font_symbols = " 0123456789:\""
    global clock_font = lutro.graphics.newImageFont("assets/imgfont/clock.png", font_symbols)
	global clock_shade_font = lutro.graphics.newImageFont("assets/imgfont/clock_shade.png", font_symbols)
end

function GameTimer:decrement(dt: number)
	self.time_left = self.time_left - dt
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

local function draw_clock_text(clock_text: string)
	lutro.graphics.setFont(clock_shade_font)
    for dx=1, 0, -1 do
        for dy=1, 0, -1 do
            if dx == 0 and dy == 0 then
                lutro.graphics.setFont(clock_font)
            end
            lutro.graphics.print(clock_text, TIMER_X_POS + dx, TIMER_Y_POS + dy)
        end
    end
end

function GameTimer:draw()
	local clock_text = time_to_clock_text(self.time_left)
	draw_clock_text(clock_text)
end

function GameTimer:finished(): boolean
	return self.time_left <= 0.0
end
