local init = require("level_graphics.maps.init") 


local soft_block_animations = {}

function soft_block_animations.get_rigid(): Animation
    return init.get_graphics():get_soft_block_rigid()
end

function soft_block_animations.get_exploding(): Animation
    return init.get_graphics():get_soft_block_exploding()
end

return soft_block_animations
