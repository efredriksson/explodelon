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

local record CheckPerformanceOfScene is Scene
    to_wrap: Scene
    load: function(self)
    update: function(self, dt: number)
    draw: function(self)
    is_internal: boolean
end

function CheckPerformanceOfScene.new(to_wrap: Scene): CheckPerformanceOfScene
   local self: CheckPerformanceOfScene = setmetatable({}, { __index = CheckPerformanceOfScene })
   self.to_wrap = to_wrap
   self.is_internal = true
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
    local tracing_start = tracing.setup("main update")
    self.to_wrap:update(dt)
    warn_if_took_too_long(tracing_start)
end

function CheckPerformanceOfScene:draw()
    local tracing_start = tracing.setup("main draw")
    self.to_wrap:draw()
    warn_if_took_too_long(tracing_start)
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
