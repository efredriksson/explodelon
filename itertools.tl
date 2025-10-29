global record LoopIndex
	start: integer
	end_: integer
	step: integer
end

local itertools = {}

function itertools.new_loop(start: integer, end_: integer, step?: integer): LoopIndex
   local self: LoopIndex = setmetatable({}, { __index = LoopIndex })
   self.start = start
   self.end_ = end_
   self.step = step or 1
   return self
end

function LoopIndex:reverse(): LoopIndex
	return itertools.new_loop(self.end_, self.start, -1 * self.step)
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

function itertools.double_loop_inner_loopback(
	outer_range: {integer, integer, integer}, inner_range: {integer, integer, integer}
): function(): integer, integer
	local outer = itertools.new_loop(outer_range[1], outer_range[2], outer_range[3])
	local inner = itertools.new_loop(inner_range[1], inner_range[2], inner_range[3])
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

function itertools.combine<T>(...: {T}): {T}
	local combined_list: {T} = {}
	
	for _, list in ipairs({...}) do
		for _, elem in ipairs(list) do
			table.insert(combined_list, elem)
		end
	end

   	return combined_list
end

function itertools.map<T, V>(iterator: {T}, f: function(T): V): {V}
    local result = {}
    for _, args in ipairs(iterator) do
        table.insert(result, f(args))
    end
    return result
end

function itertools.filter<T>(iterator: {T}, predicate: function(T): boolean): {T}
    local result = {}
    for _, element in ipairs(iterator) do
		if predicate(element) then
	        table.insert(result, element)
		end
    end
    return result
end

function itertools.shuffle<T>(t: {T}): {T}
	-- https://stackoverflow.com/a/68486276
	local s = {}
	for i = 1, #t do s[i] = t[i] end
	for i = #t, 2, -1 do
		local j = lutro.math.random(i)
		s[i], s[j] = s[j], s[i]
	end
	return s
end

return itertools
