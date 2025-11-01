local record Settings
    number_of_players: integer
    player_selection: boolean
    draw_hitboxes: boolean
    nbr_soft_blocks: integer
    start_with_kick: boolean
end


function Settings.new(): Settings
    local self: Settings = setmetatable({}, { __index = Settings })
    self.number_of_players = 2
    self.player_selection = true
    self.draw_hitboxes = false
    self.nbr_soft_blocks = 105
    self.start_with_kick = false
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

function Settings.set_nbr_soft_blocks(value: integer)
    settings.nbr_soft_blocks = value
end

function Settings.set_start_with_kick(value: boolean)
    settings.start_with_kick = value
end

return settings
