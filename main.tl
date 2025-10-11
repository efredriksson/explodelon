require("const")
require("scene")

function lutro.conf(t: Configuration)
	t.width  = MAP_WIDTH
	t.height = MAP_HEIGHT
end

function lutro.load()
	set_scene(require("start_menu"))
end

function lutro.update(dt: number)
	get_scene().update(dt)
end

function lutro.gamepadpressed(_: integer, button: GamepadButton)
	get_scene().gamepadpressed(button)
end

function lutro.gamepadreleased(_: integer, _: GamepadButton)
	-- Must be defined for 'gamepadpressed' to work properly
end

function lutro.draw()
	get_scene().draw()
end
