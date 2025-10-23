require("const")

local previous_states: {integer: {integer: boolean}} = {}

-- Used to check if a button was just pressed this frame (not held)
global function joystick_is_pressed(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id][button]

    return is_currently_down and not was_previously_down
end

-- Used to check if a button was released this frame
global function joystick_is_released(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id][button]

    return not is_currently_down and was_previously_down
end

global function input_setup()
    for player_id = 1, MAX_PLAYERS do
        previous_states[player_id] = {}
        for button = 1, MAX_BUTTONS do
            previous_states[player_id][button] = false
        end
    end
end

global function input_update()
    for player_id, previous_state in pairs(previous_states) do
        for button, _ in pairs(previous_state) do
            previous_state[button] = lutro.joystick.isDown(player_id, button)
        end
    end
end
