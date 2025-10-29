

global type Scene = interface
    load: function(self)
    update: function(self, dt: number)
    draw: function(self)
end

local record WrapperScene is Scene
    to_wrap: Scene
    load: function(self)
    update: function(self, dt: number)
    draw: function(self)
end

function WrapperScene.new(to_wrap: Scene): WrapperScene
   local self: WrapperScene = setmetatable({}, { __index = WrapperScene })
   self.to_wrap = to_wrap
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

local current_scene: Scene

global function get_scene(): Scene
    return current_scene
end

global function set_scene(scene: Scene)
    current_scene = WrapperScene.new(scene)
    current_scene:load()
end
