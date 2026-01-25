require("engine.animations")


global type MapGraphics = interface
    draw_background: function(self)
    get_soft_block_rigid: function(self): Animation
    get_soft_block_exploding: function(self): Animation
    get_hard_block: function(self, boolean): Animation
    load_assets: function(self)
end
