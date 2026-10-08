-- Tile maps for grid walk specs, drawn as rows of '.' (open) and '#' (blocked).
local tile_map = {TILE = 16}

--- The is_open predicate for a drawn map; outside the drawing is blocked.
function tile_map.tiles(rows)
    return function(i, j)
        local row = rows[j + 1]
        return row ~= nil and row:sub(i + 1, i + 1) == "."
    end
end

return tile_map
