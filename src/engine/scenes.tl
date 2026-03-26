local logger = require("engine.logger")
local settings = require("engine.settings")
local tracing = require("engine.tracing")

local type Span = tracing.Span

local type Scene = interface
    load: function(self)
    update: function(self, dt: number)
    draw: function(self)
    -- Implementation outside this file should not have this:
    is_internal: boolean
end

local scenes = {Scene = Scene}

local record MemorySample
    frame_count: integer
    accumulated_kb: number
end

function MemorySample.new(): MemorySample
    local self: MemorySample = setmetatable({}, { __index = MemorySample })
    self.frame_count = 0
    self.accumulated_kb = 0
    return self
end

function MemorySample:start(): number
    collectgarbage("stop")
    return collectgarbage("count") as number
end

function MemorySample:record(before_kb: number, label: string)
    local after_kb = collectgarbage("count") as number
    collectgarbage("restart")
    self.accumulated_kb = self.accumulated_kb + (after_kb - before_kb)
    self.frame_count = self.frame_count + 1
    if self.frame_count >= 60 then
        local avg = self.accumulated_kb / self.frame_count
        logger.info(
            string.format(
                "mem %s allocated/frame: %+.2f KB avg over %d frames",
                label,
                avg,
                self.frame_count
            )
        )
        self.frame_count = 0
        self.accumulated_kb = 0
    end
end

local record CheckMemoryOfScene is Scene
    to_wrap: Scene
    is_internal: boolean
    update_sample: MemorySample
    draw_sample: MemorySample
end

function CheckMemoryOfScene.new(to_wrap: Scene): CheckMemoryOfScene
    local self: CheckMemoryOfScene = setmetatable({}, { __index = CheckMemoryOfScene })
    self.to_wrap = to_wrap
    self.is_internal = true
    self.update_sample = MemorySample.new()
    self.draw_sample = MemorySample.new()
    return self
end

function CheckMemoryOfScene:load()
    self.to_wrap:load()
end

function CheckMemoryOfScene:update(dt: number)
    local used_before = self.update_sample:start()
    self.to_wrap:update(dt)
    self.update_sample:record(used_before, "update")
end

function CheckMemoryOfScene:draw()
    local used_before = self.draw_sample:start()
    self.to_wrap:draw()
    self.draw_sample:record(used_before, "draw")
end

local record WrapperScene is Scene
    to_wrap: Scene
    load: function(self)
    update: function(self, dt: number)
    draw: function(self)
    is_internal: boolean
end

function WrapperScene.new(to_wrap: Scene): WrapperScene
   local self: WrapperScene = setmetatable({}, { __index = WrapperScene })
   self.to_wrap = to_wrap
   self.is_internal = true
   return self
end

function WrapperScene:load()
    if self.to_wrap.load then
        self.to_wrap:load()
    end
end

function WrapperScene:update(dt: number)
    if self.to_wrap.update then
        self.to_wrap:update(dt)
    end
end

function WrapperScene:draw()
    if self.to_wrap.draw then
        self.to_wrap:draw()
    end
end

local record PerformanceSample
    frame_count: integer
    accumulated_seconds: number
end

function PerformanceSample.new(): PerformanceSample
    local self: PerformanceSample = setmetatable({}, { __index = PerformanceSample })
    self.frame_count = 0
    self.accumulated_seconds = 0
    return self
end

function PerformanceSample:start(): number
    return lutro.timer.getTime()
end

function PerformanceSample:record(before_seconds: number, label: string)
    self.accumulated_seconds = self.accumulated_seconds + (lutro.timer.getTime() - before_seconds)
    self.frame_count = self.frame_count + 1
    if self.frame_count >= 300 then
        local avg_ms = (self.accumulated_seconds / self.frame_count) * 1000
        logger.info(
            string.format(
                "perf %s avg/frame: %.1f ms avg over %d frames",
                label,
                avg_ms,
                self.frame_count
            )
        )
        self.frame_count = 0
        self.accumulated_seconds = 0
    end
end

local record CheckPerformanceOfScene is Scene
    to_wrap: Scene
    is_internal: boolean
    update_sample: PerformanceSample
    draw_sample: PerformanceSample
end

function CheckPerformanceOfScene.new(to_wrap: Scene): CheckPerformanceOfScene
   local self: CheckPerformanceOfScene = setmetatable({}, { __index = CheckPerformanceOfScene })
   self.to_wrap = to_wrap
   self.is_internal = true
   self.update_sample = PerformanceSample.new()
   self.draw_sample = PerformanceSample.new()
   return self
end

function CheckPerformanceOfScene:load()
    self.to_wrap:load()
end

local function warn_if_took_too_long(top_level_tracing: Span)
    top_level_tracing:stop()
    local limit_to_log_time = 0.003
    if top_level_tracing.elapsed > limit_to_log_time then
        logger.warning(top_level_tracing:report())
    end
end

function CheckPerformanceOfScene:update(dt: number)
    local used_before = self.update_sample:start()
    local tracing_start = tracing.setup("main update")
    self.to_wrap:update(dt)
    warn_if_took_too_long(tracing_start)
    self.update_sample:record(used_before, "update")
end

function CheckPerformanceOfScene:draw()
    local used_before = self.draw_sample:start()
    local tracing_start = tracing.setup("main draw")
    self.to_wrap:draw()
    warn_if_took_too_long(tracing_start)
    self.draw_sample:record(used_before, "draw")
end

local current_scene: Scene
local start_scene: Scene

function scenes.get(): Scene
    return current_scene
end

function scenes.set(scene: Scene, skip_loading?: boolean)
    if not scene.is_internal then
        scene = WrapperScene.new(scene)
        if settings.log_scene_perf then
            scene = CheckPerformanceOfScene.new(scene)
        end
        if settings.log_mem_usage then
            scene = CheckMemoryOfScene.new(scene)
        end
    end

    current_scene = scene
    if not skip_loading then
        current_scene:load()
    end
end

function scenes.set_start(scene: Scene)
    start_scene = scene
    scenes.set(scene)
end

function scenes.return_to_start()
    assert(start_scene, "implementation error")
    scenes.set(start_scene)
end

return scenes
