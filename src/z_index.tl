local type Entity = require("engine.entity")

local z_index = {
    BELOW = -3, -- On ground and you walk over it
    LEVEL = 0, -- Ground level, walk/moving
    ABOVE = 3, -- Above/Flying above
}

function z_index.back_to_front(first: Entity, second: Entity): boolean
    if first.z_index ~= second.z_index then
        return first.z_index < second.z_index
    end
    local pos1 = first:get_position()
    local pos2 = second:get_position()
    if pos1.y ~= pos2.y then
        return pos1.y < pos2.y
    end
    if pos1.x ~= pos2.x then
        return pos1.x < pos2.x
    end
    -- tostring gives a stable memory-address-based order within a session,
    -- preventing flickering for entities at identical positions.
    return tostring(first) < tostring(second)
end

return z_index
