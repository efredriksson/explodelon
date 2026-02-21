
local interface Span
    name: string
    elapsed: number
    stop: function(self)
    report: function(self): string
end

local record SpanTiming is Span
    previous_level: SpanTiming
    next_levels: {SpanTiming}
    start_time: number
end

local current_level: SpanTiming = nil

local tracing = {Span = Span}

function SpanTiming.new(name: string, previous_level: SpanTiming): SpanTiming
    local self: SpanTiming = setmetatable({}, { __index = SpanTiming })
    self.name = name
    self.previous_level = previous_level
    self.next_levels = {}
    self.start_time = lutro.timer.getTime()
    self.elapsed = 0
    return self
end

local record SpanDummy is Span
end

function SpanDummy.new(): SpanDummy
    local self: SpanDummy = setmetatable({}, { __index = SpanDummy })
    self.name = "dummy"
    self.elapsed = 1234
    return self
end

function SpanDummy:stop()
    -- Does nothing
end

function SpanDummy:report(): string
    assert(false, "Can't get tracing report when not setup")
end

function SpanTiming:stop()
    self.elapsed = lutro.timer.getTime() - self.start_time
    current_level = self.previous_level
end

local DUMMY_TRACE_SPAM<const> = SpanDummy.new()

function tracing.start(name: string): Span
    if not current_level then
        -- If tracing has not been setup, then use dummy for codebase
        return DUMMY_TRACE_SPAM
    end

    local span_next_level = SpanTiming.new(name, current_level)
    table.insert(current_level.next_levels, span_next_level)
    
    -- Then current level is next level until we stop/exit that level
    current_level = span_next_level
    return span_next_level
end

function tracing.setup(name: string): Span
    current_level = SpanTiming.new(name, nil)
    return current_level
end

function tracing.reset()
    current_level = nil
end

function SpanTiming:_reqursive_report(indentation: string): string
    local parts: {string} = {}
    table.insert(parts, indentation .. self.name .. ": " .. string.format("%.1f", self.elapsed * 1000) .. "ms")
    for _, next_level in ipairs(self.next_levels) do
        table.insert(parts, next_level:_reqursive_report(indentation .. "  "))
    end

    return table.concat(parts, "\n")
end

function SpanTiming:report(): string
    assert(self.previous_level == nil, "Should only create report for top-level span")
    return "Tracing " .. self:_reqursive_report("")
end

return tracing
