global record LoopIndex
	start: integer
	end_: integer
	step: integer
end

function LoopIndex.new(start: integer, end_: integer, step?: integer): LoopIndex
   local self: LoopIndex = setmetatable({}, { __index = LoopIndex })
   self.start = start
   self.end_ = end_
   self.step = step or 1
   return self
end

function LoopIndex:reverse(): LoopIndex
	return LoopIndex.new(self.end_, self.start, -1 * self.step)
end

function LoopIndex:values(): function(): integer
	local val = self.start - self.step
	local function value_iterator(): integer
		val = val + self.step
		if (val <= self.end_ and self.step > 0) or (val >= self.end_ and self.step < 0) then
			return val
		end
	end

	return value_iterator
end

global function double_loop_inner_loopback(
	outer_range: {integer, integer, integer}, inner_range: {integer, integer, integer}
): function(): integer, integer
	local outer = LoopIndex.new(outer_range[1], outer_range[2], outer_range[3])
	local inner = LoopIndex.new(inner_range[1], inner_range[2], inner_range[3])
	local values: {{integer, integer}} = {}
	for j in outer:values() do
		for i in inner:values() do
			table.insert(values, {j, i})
		end
		inner = inner:reverse()
	end

    local i = 0
    local n = #values
    return function (): integer, integer
        i = i + 1
        if i <= n then return values[i][1], values[i][2] end
    end
end
