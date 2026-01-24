local init = require("level_graphics.init") 


local background = {}

function background.draw()
    return init.get_graphics():draw_background()
end

return background
