local const = require("const")
local scenes = require("scenes")
local joysticks = require("joysticks")
local start_menu = require("start_menu")

function lutro.conf(t: Configuration)
	t.width  = const.MAP_WIDTH
	t.height = const.MAP_HEIGHT
end

function lutro.load()
	joysticks.setup()
	scenes.set(start_menu.new())
end

function lutro.update(dt: number)
	scenes.get():update(dt)
	joysticks.update()
end

function lutro.draw()
	scenes.get():draw()
end
