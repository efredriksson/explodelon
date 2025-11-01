local record Settings
    number_of_players: integer
    player_selection: boolean
    draw_hitboxes: boolean
end


function Settings.new(): Settings
    local self: Settings = setmetatable({}, { __index = Settings })
    self.number_of_players = 2
    self.player_selection = true
    self.draw_hitboxes = false
    return self
end

local settings = Settings.new()

function Settings.set_player_selection(value: boolean)
    settings.player_selection = value
end

function Settings.set_draw_hitboxs(value: boolean)
    settings.draw_hitboxes = value
end

function Settings.set_number_of_players(value: integer)
    settings.number_of_players = value
end

return settings
