global record Scene
   load: function()
   update: function(dt: number)
   draw: function()
end

local function default_load()
end

local function default_update(_: number)
end

local function default_draw()
end

function Scene.new(): Scene
    local self: Scene = setmetatable({}, { __index = Scene })
    self.load = default_load
    self.update = default_update
    self.draw = default_draw
    return self
end

local current_scene: Scene

global function get_scene(): Scene
    return current_scene
end

global function set_scene(scene: Scene)
    current_scene = scene
    current_scene.load()
end
