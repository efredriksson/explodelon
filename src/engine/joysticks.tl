local settings = require("engine.settings")

local previous_states: {integer: {integer: boolean}} = {}
local down_for_states: {integer: {integer: number}} = {}
local joysticks = {
    MAX_BUTTONS = 16,
    BUTTONS = {
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
    },
}

function joysticks.maxplayers(): integer
    if settings.get_features().HAVE_16_JOYSTICKS then
        return 10
    else
        return 8
    end
end

-- Used to check if a button was just pressed this frame (not held)
function joysticks.is_pressed(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id][button]

    return is_currently_down and not was_previously_down
end

-- Used to check if a button was just pressed this frame (not held) by any player
function joysticks.is_pressed_any(button: integer): boolean
    for player_id=1, joysticks.maxplayers() do
        if joysticks.is_pressed(player_id, button) then
            return true
        end
    end
    
    return false
end

-- Used to check if a button was released this frame
function joysticks.is_released(player_id: integer, button: integer): boolean
    local is_currently_down = lutro.joystick.isDown(player_id, button)
    local was_previously_down = previous_states[player_id][button]

    return not is_currently_down and was_previously_down
end

-- Used to check if a button has been pressed down 
function joysticks.is_down_for(player_id: integer, button: integer, time: number): boolean
    return down_for_states[player_id][button] >= time
end

-- Used to check if a button has been pressed down by any player
function joysticks.is_down_for_any(button: integer, time: number): boolean
    for player_id=1, joysticks.maxplayers() do
        if joysticks.is_down_for(player_id, button, time) then
            return true
        end
    end
    
    return false
end

function joysticks.setup()
    for player_id = 1, joysticks.maxplayers() do
        previous_states[player_id] = {}
        down_for_states[player_id] = {}
        for button = 1, joysticks.MAX_BUTTONS do
            previous_states[player_id][button] = false
            down_for_states[player_id][button] = 0
        end
    end
end

function joysticks.update(dt: number)
    for player_id, previous_state in pairs(previous_states) do
        for button, _ in pairs(previous_state) do
            local down_for_state = down_for_states[player_id]
            if lutro.joystick.isDown(player_id, button) then
                previous_state[button] = true
                down_for_state[button] = down_for_state[button] + dt
            else
                previous_state[button] = false
                down_for_state[button] = 0
            end
        end
    end
end

return joysticks
