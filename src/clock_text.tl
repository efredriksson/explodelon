local clock_text = {}

function clock_text.from_time(time_in_sec: number): string
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

return clock_text
