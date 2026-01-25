local const = require("const")
local joysticks = require("engine.joysticks")
local logger = require("engine.logger")
local scenes = require("engine.scenes")
local screens = require("menus.screens")
local start_screen = require("menus.start_screen")
local player_selection = require("player_selection")
local game = require("game")

function lutro.conf(t: Configuration)
	t.width  = const.MAP_WIDTH
	t.height = const.MAP_HEIGHT
end

function lutro.load()
	local load_start = lutro.timer.getTime()
	joysticks.setup()
	screens.load_assets()
	player_selection.load_assets()
	game.load_assets()
	local load_time = lutro.timer.getTime() - load_start
	logger.info("Loading assets at start took " .. load_time .. "s")
	scenes.set_start(start_screen.new())
end

function lutro.update(dt: number)
	scenes.get():update(dt)
	joysticks.update(dt)
end

function lutro.draw()
	scenes.get():draw()
end
