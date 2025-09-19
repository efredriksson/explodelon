require("const")
require("scene")

global scene: Scene = require("game")

function lutro.conf(t: Configuration)
	t.width  = MAP_WIDTH
	t.height = MAP_HEIGHT
end

function lutro.load()
	scene.load()
end

function lutro.update(dt: number)
	scene.update(dt)
end

function lutro.gamepadpressed(_: integer, button: GamepadButton)
	scene.gamepadpressed(button)
end

function lutro.gamepadreleased(_: integer, _: GamepadButton)
	-- Must be defined for 'gamepadpressed' to work properly
end

function lutro.draw()
	scene.draw()
end
