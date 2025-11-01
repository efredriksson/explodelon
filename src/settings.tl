global enum ItemType
   "speed"
   "bomb"
   "kick"
   "fire"
end

local record TimingRules
    battle: number
    sudden_death: number
end

function TimingRules.new(): TimingRules
    local self: TimingRules = setmetatable({}, { __index = TimingRules })
    self.battle = 180
    self.sudden_death = 60
    return self
end

local record ItemRules
    nbr_soft_blocks: integer
    nbr_of_eggs: integer
    nbr_of_items: {ItemType: integer}
    spawn_rates: {ItemType: number}
end

function ItemRules.new(): ItemRules
    local self: ItemRules = setmetatable({}, { __index = ItemRules })
    self.nbr_soft_blocks = 105
    self.nbr_of_eggs = 4
    self.nbr_of_items = {
        bomb = 8,
        fire = 6,
        speed = 4,
        kick = 8,
    }
    self.spawn_rates = {
        bomb = 0,
        fire = 0,
        speed = 0,
        kick = 0,
    }
    return self
end

local record PlayerRules
    start_position_shuffle: boolean
    mad_bombers: boolean
    start_speed: integer
    start_with_kick: boolean
end

function PlayerRules.new(): PlayerRules
    local self: PlayerRules = setmetatable({}, { __index = PlayerRules })
    self.start_position_shuffle = true
    self.mad_bombers = true
    self.start_speed = 60
    self.start_with_kick = false
    return self
end

local record GameRules
    players: PlayerRules
    items: ItemRules
    timings: TimingRules
end

function GameRules.new(): GameRules
    local self: GameRules = setmetatable({}, { __index = GameRules })
    self.players = PlayerRules.new()
    self.items = ItemRules.new()
    self.timings = TimingRules.new()
    return self
end

local record Debug
    draw_hitboxes: boolean
end

function Debug.new(): Debug
    local self: Debug = setmetatable({}, { __index = Debug })
    self.draw_hitboxes = false
    return self
end

local record Settings
    number_of_players: integer
    player_selection: boolean
    game_rules: GameRules
    debug: Debug
end

function Settings.new(): Settings
    local self: Settings = setmetatable({}, { __index = Settings })
    self.number_of_players = 2
    self.player_selection = true
    self.game_rules = GameRules.new()
    self.debug = Debug.new()
    return self
end

local settings = Settings.new()

function Settings.set_player_selection(value: boolean)
    settings.player_selection = value
end

function Settings.set_draw_hitboxs(value: boolean)
    settings.debug.draw_hitboxes = value
end

function Settings.set_number_of_players(value: integer)
    settings.number_of_players = value
end

function Settings.set_nbr_soft_blocks(value: integer)
    settings.game_rules.items.nbr_soft_blocks = value
end

function Settings.set_nbr_of_eggs(value: integer)
    settings.game_rules.items.nbr_of_eggs = value
end

function Settings.set_nbr_of_bombs(value: integer)
    settings.game_rules.items.nbr_of_items.bomb = value
end

function Settings.set_nbr_of_fire(value: integer)
    settings.game_rules.items.nbr_of_items.fire = value
end

function Settings.set_nbr_of_speed(value: integer)
    settings.game_rules.items.nbr_of_items.speed = value
end

function Settings.set_nbr_of_kick(value: integer)
    settings.game_rules.items.nbr_of_items.kick = value
end

function Settings.set_start_position_shuffle(value: boolean)
    settings.game_rules.players.start_position_shuffle = value
end

function Settings.set_mad_bombers(value: boolean)
    settings.game_rules.players.mad_bombers = value
end

function Settings.set_start_speed(value: integer)
    settings.game_rules.players.start_speed = value
end

function Settings.set_start_with_kick(value: boolean)
    settings.game_rules.players.start_with_kick = value
end

function Settings.set_battle_time(value: number)
    settings.game_rules.timings.battle = value
end

function Settings.set_sudden_death_time(value: number)
    settings.game_rules.timings.sudden_death = value
end

function Settings.set_game_rules_default()
    settings.game_rules = GameRules.new()
end

function Settings.set_game_rules_kick_debug()
    settings.game_rules = GameRules.new()
    settings.game_rules.players.start_with_kick = true
    settings.game_rules.items.nbr_soft_blocks = 0
end

function Settings.set_game_rules_insanity()
    settings.game_rules = GameRules.new()
    settings.game_rules.items.nbr_soft_blocks = 30
    settings.game_rules.timings.battle = 80
    settings.game_rules.timings.sudden_death = 50
    settings.game_rules.items.spawn_rates.speed = 0.3
    settings.game_rules.items.spawn_rates.bomb = 0.3
    settings.game_rules.items.spawn_rates.fire = 0.5
    settings.game_rules.items.spawn_rates.kick = 0.07
    settings.game_rules.players.mad_bombers = false
end

return settings
