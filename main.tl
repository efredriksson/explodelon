require("const")
require("scene")
require("input")
local start_menu = require("start_menu")

function lutro.conf(t: Configuration)
	t.width  = MAP_WIDTH
	t.height = MAP_HEIGHT
end

function lutro.load()
	input_setup()
	set_scene(start_menu)
end

function lutro.update(dt: number)
	get_scene():update(dt)
	input_update()
end

function lutro.draw()
	get_scene():draw()
end
