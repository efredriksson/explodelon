require("const")
require("player")

local previous_states: {integer: {integer: boolean}} = {}

-- Used to check if a button was just pressed this frame (not held)
global function joystick_is_pressed(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id] and previous_states[player_id][button]

    return is_currently_down and not was_previously_down
end

global function input_update(players: {Player})
    for _, player in ipairs(players) do
        if not previous_states[player.id] then
            previous_states[player.id] = {}
        end

        for button = 1, 16 do
            previous_states[player.id][button] = lutro.joystick.isDown(player.id, button)
        end
    end
end