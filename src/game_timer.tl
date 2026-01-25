local audio = require("engine.audio")
local clock_text = require("clock_text")
local fonts = require("fonts")
local itertools = require("itertools")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local screen = require("screen")
local settings = require("settings")


local TIMER_POS = points.new(18, 8)
local WARNING_MARGIN = 2
local TEXT_X_SPEED = vectors.new(-200, 0)
local TEXT_SIN_PERIOD = 9
local TEXT_SIN_AMPLITUDE = 5

global record GameTimer
   time_left: number
   have_played_hurry_up_sound: boolean
   hurry_text_position: Point
   hurry_text_sin_pos: number
   hurry_text_mid_countdown: number
end

local clock_font: ShadedFont
local hurry_letters: {Image}
local hurry_letters_mid: number
local hurry_letters_start: Point
local hurry_up_sound: Source
local game_timer = {}

function game_timer.new(): GameTimer
   local self: GameTimer = setmetatable({}, { __index = GameTimer })
   self.time_left = settings.game_rules.timings.battle
   self.have_played_hurry_up_sound = false
   self.hurry_text_position = hurry_letters_start
   self.hurry_text_sin_pos = math.pi
   self.hurry_text_mid_countdown = 1
   return self
end

function GameTimer.load_assets()
	clock_font = fonts.new_shaded_numbers()
	hurry_up_sound = audio.new_source("assets/hurry-up.wav", "static")

	local function img_letter(letter: string): Image
		return lutro.graphics.newImage("assets/imgfont/" .. letter .. ".png")
	end

	hurry_letters = itertools.map({"h", "u", "r", "r", "y", "!"}, img_letter)
	local letter_box_width = 0.0
	for _, letter in ipairs(hurry_letters) do
		letter_box_width = letter_box_width + letter:getWidth()
	end
	hurry_letters_mid = (screen.WIDTH - letter_box_width) / 2
	hurry_letters_start = points.new(
		screen.WIDTH,
		(screen.HEIGHT - hurry_letters[1]:getHeight()) / 2
	)
end

function GameTimer:finished(): boolean
	return self.time_left <= 0.0
end

function GameTimer:sudden_death(): boolean
	return self.time_left <= settings.game_rules.timings.sudden_death
end

function GameTimer:warn_for_sudden_death(): boolean
	return self.time_left - WARNING_MARGIN <= settings.game_rules.timings.sudden_death
end

function GameTimer:update(dt: number)
	self.time_left = self.time_left - dt
	if self:warn_for_sudden_death() and not self.have_played_hurry_up_sound then
		self.have_played_hurry_up_sound = true
		hurry_up_sound:play()
	end
	if self:warn_for_sudden_death() then
		if self.hurry_text_position.x < hurry_letters_mid and self.hurry_text_mid_countdown > 0 then
			self.hurry_text_mid_countdown = self.hurry_text_mid_countdown - dt
		else
			self.hurry_text_position = self.hurry_text_position:move(TEXT_X_SPEED:scale(dt))
		end
		self.hurry_text_sin_pos = self.hurry_text_sin_pos + TEXT_SIN_PERIOD * dt
		self.hurry_text_sin_pos = math.fmod(self.hurry_text_sin_pos, 2*math.pi)
	end
end

function GameTimer:out_of_time(): boolean
	return self.time_left < 0
end

function GameTimer:draw()
	local text = clock_text.from_time(self.time_left)
	clock_font:draw(text, TIMER_POS)
end

function GameTimer:draw_hurry_text()
	local letter_position = self.hurry_text_position
	local letter_sin_pos = self.hurry_text_sin_pos
	for _, letter in ipairs(hurry_letters) do
		local y_pos = letter_position.y + math.sin(letter_sin_pos) * TEXT_SIN_AMPLITUDE
		lutro.graphics.draw(letter, letter_position.x, y_pos)
		letter_position = letter_position:move(vectors.new(letter:getWidth(), 0))
		letter_sin_pos = letter_sin_pos + math.pi / 5
	end
end

return game_timer
