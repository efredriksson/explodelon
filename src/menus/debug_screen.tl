local scenes = require("engine.scenes")
local choices = require("menus.choices")
local screens = require("menus.screens")
local settings = require("engine.settings")


local debug_screen = {}

function debug_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    return screens.new({
        choices.new_boolean(
            "draw hitboxes", 50, settings.draw_hitboxes, settings.set_draw_hitboxs
        ),
        choices.new_boolean(
            "log slow game loop", 70, settings.log_scene_perf, settings.set_log_scene_perf
        ),
        choices.new_done("back", 180, done)
    }, done)
end

return debug_screen
