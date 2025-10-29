local const = require("const")

local previous_states: {integer: {integer: boolean}} = {}
local joysticks = {}

function joysticks.buttons(): {string: integer}
    return {
        B        = 1,
        Y        = 2,
        SELECT   = 3,
        START    = 4,
        UP       = 5,
        DOWN     = 6,
        LEFT     = 7,
        RIGHT    = 8,
        A        = 9,
        X        = 10,
        L        = 11,
        R        = 12,
        L2       = 13,
        R2       = 14,
        L3       = 15,
        R3       = 16,
    }
end

-- Used to check if a button was just pressed this frame (not held)
function joysticks.is_pressed(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id][button]

    return is_currently_down and not was_previously_down
end

-- Used to check if a button was released this frame
function joysticks.is_released(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id][button]

    return not is_currently_down and was_previously_down
end

function joysticks.setup()
    for player_id = 1, const.MAX_PLAYERS do
        previous_states[player_id] = {}
        for button = 1, const.MAX_BUTTONS do
            previous_states[player_id][button] = false
        end
    end
end

function joysticks.update()
    for player_id, previous_state in pairs(previous_states) do
        for button, _ in pairs(previous_state) do
            previous_state[button] = lutro.joystick.isDown(player_id, button)
        end
    end
end

return joysticks
