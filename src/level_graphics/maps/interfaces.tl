local animations = require("engine.animations")

local type Animation = animations.Animation

local type MapGraphics = interface
    draw_background: function(self)
    get_soft_block_rigid: function(self): Animation
    get_soft_block_revealed: function(self): Animation
    get_soft_block_exploding: function(self): Animation
    get_hard_block: function(self, boolean): Animation
    load_assets: function(self)
end

return MapGraphics
