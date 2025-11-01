global enum ItemType
   "speed"
   "bomb"
   "kick"
   "fire"
end

local record Settings
    number_of_players: integer
    player_selection: boolean
    draw_hitboxes: boolean
    nbr_soft_blocks: integer
    nbr_of_eggs: integer
    nbr_of_items: {ItemType: integer}
    start_position_shuffle: boolean
    mad_bombers: boolean
    start_speed: integer
    start_with_kick: boolean
    battle_time: number
    sudden_death_time: number
end

function Settings.new(): Settings
    local self: Settings = setmetatable({}, { __index = Settings })
    self.number_of_players = 2
    self.player_selection = true
    self.draw_hitboxes = false
    self.nbr_soft_blocks = 105
    self.nbr_of_eggs = 4
    self.nbr_of_items = {
        bomb = 8,
        fire = 6,
        speed = 4,
        kick = 8,
    }
    self.start_position_shuffle = true
    self.mad_bombers = true
    self.start_speed = 60
    self.start_with_kick = false
    self.battle_time = 180
    self.sudden_death_time = 60

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

function Settings.set_nbr_of_eggs(value: integer)
    settings.nbr_of_eggs = value
end

function Settings.set_nbr_of_bombs(value: integer)
    settings.nbr_of_items.bomb = value
end

function Settings.set_nbr_of_fire(value: integer)
    settings.nbr_of_items.fire = value
end

function Settings.set_nbr_of_speed(value: integer)
    settings.nbr_of_items.speed = value
end

function Settings.set_nbr_of_kick(value: integer)
    settings.nbr_of_items.kick = value
end

function Settings.set_start_position_shuffle(value: boolean)
    settings.start_position_shuffle = value
end

function Settings.set_mad_bombers(value: boolean)
    settings.mad_bombers = value
end

function Settings.set_start_speed(value: integer)
    settings.start_speed = value
end

function Settings.set_start_with_kick(value: boolean)
    settings.start_with_kick = value
end

function Settings.set_battle_time(value: number)
    settings.battle_time = value
end

function Settings.set_sudden_death_time(value: number)
    settings.sudden_death_time = value
end

return settings
