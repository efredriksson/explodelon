local scenes = require("scenes")
local settings = require("settings")
local choices = require("menus.choices")
local srceens = require("menus.screens")

local debug_screen = {}

function debug_screen.new(previous_screen: Scene): MenuScreen
    local function done(_: Scene)
        scenes.set(previous_screen)
    end

    return srceens.new({
        choices.new_boolean(
            "draw hitboxes", 50, settings.draw_hitboxes, settings.set_draw_hitboxs
        ),
        choices.new_done("back", 180, done)
    })
end

return debug_screen
