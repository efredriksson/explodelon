local joysticks = require("engine.joysticks")
local logger = require("engine.logger")
local scenes = require("engine.scenes")
local settings = require("engine.settings")
local tracing = require("engine.tracing")
local battle = require("game.battle")
local grid = require("level_layout.grid")
local screens = require("menus.screens")
local start_screen = require("menus.start_screen")
local update_screen = require("menus.update_screen")
local player_selection = require("player_selection")
local screen = require("screen")
local team_selection = require("team_selection")

function lutro.conf(t: Configuration)
	-- fmt: off
	t.width  = screen.WIDTH
	t.height = screen.HEIGHT
    -- fmt: on
end

function lutro.load()
    logger.setup("EXPLODELON")
    settings.set_block_size(grid.TILE_SIZE)
    local load_start = lutro.timer.getTime()
    joysticks.setup()
    screens.load_assets()
    player_selection.load_assets()
    team_selection.load_assets()
    battle.load_assets()
    update_screen.load_assets()
    local load_time = lutro.timer.getTime() - load_start
    logger.info("Loading assets at start took " .. load_time .. "s")
    scenes.set_start(start_screen.new())
end

function lutro.update(dt: number)
    tracing.reset()
    scenes.get():update(dt)
    joysticks.update(dt)
end

function lutro.draw()
    tracing.reset()
    scenes.get():draw()
end
