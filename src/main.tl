local const = require("const")
local joysticks = require("joysticks")
local scenes = require("scenes")
local screens = require("menus.screens")
local start_screen = require("menus.start_screen")

function lutro.conf(t: Configuration)
	t.width  = const.MAP_WIDTH
	t.height = const.MAP_HEIGHT
end

function lutro.load()
	joysticks.setup()
	screens.load_assets()
	scenes.set(start_screen.new())
end

function lutro.update(dt: number)
	scenes.get():update(dt)
	joysticks.update()
end

function lutro.draw()
	scenes.get():draw()
end
