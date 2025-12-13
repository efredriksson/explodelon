global enum ItemType
   "speed"
   "bomb"
   "kick"
   "fire"
   "lightning_bomb"
end

local record TimingRules
    nbr_battles: integer
    battle: number
    sudden_death: number
end

function TimingRules.new(): TimingRules
    local self: TimingRules = setmetatable({}, { __index = TimingRules })
    self.nbr_battles = 3
    self.battle = 180
    self.sudden_death = 60
    return self
end

local record ItemRules
    nbr_soft_blocks: integer
    nbr_of_items: {ItemType: integer}
    spawn_rates: {ItemType: number}
end

function ItemRules.new(): ItemRules
    local self: ItemRules = setmetatable({}, { __index = ItemRules })
    self.nbr_soft_blocks = 105
    self.nbr_of_items = {
        bomb = 8,
        lightning_bomb = 0,
        fire = 6,
        speed = 4,
        kick = 8,
    }
    self.spawn_rates = {
        bomb = 0,
        lightning_bomb = 0,
        fire = 0,
        speed = 0,
        kick = 0,
    }
    return self
end

local record MadBombers
    enabled: boolean
    after_sudden_death: boolean
end

function MadBombers.new(): MadBombers
    local self: MadBombers = setmetatable({}, { __index = MadBombers })
    self.enabled = true
    self.after_sudden_death = false
    return self
end

local record PlayerRules
    start_position_shuffle: boolean
    mad_bombers: MadBombers
    start_speed: integer
    start_with_kick: boolean
    start_with_bombs: integer
    start_with_lightning_bombs: integer
    start_with_fire: integer
end

function PlayerRules.new(): PlayerRules
    local self: PlayerRules = setmetatable({}, { __index = PlayerRules })
    self.start_position_shuffle = true
    self.mad_bombers = MadBombers.new()
    self.start_speed = 60
    self.start_with_kick = false
    self.start_with_bombs = 1
    self.start_with_lightning_bombs = 0
    self.start_with_fire = 2
    return self
end

global type DinoColor = enum
    "blue"
    "pink"
    "purple"
    "green"
    "yellow"
end

local record DinoRules
    nbr_of_eggs: integer
    enabled: {DinoColor: boolean}
end

function DinoRules.new(): DinoRules
    local self: DinoRules = setmetatable({}, { __index = DinoRules })
    local enabled <total>: {DinoColor: boolean} = {
        blue=true,
        pink=true,
        purple=true,
        green=true,
        yellow=true,
    }

    self.nbr_of_eggs = 4
    self.enabled = enabled
    return self
end

local record GameRules
    players: PlayerRules
    items: ItemRules
    timings: TimingRules
    dinos: DinoRules
end

function GameRules.new(): GameRules
    local self: GameRules = setmetatable({}, { __index = GameRules })
    self.players = PlayerRules.new()
    self.items = ItemRules.new()
    self.timings = TimingRules.new()
    self.dinos = DinoRules.new()
    return self
end

local record Debug
    draw_hitboxes: boolean
    log_scene_perf: boolean
end

function Debug.new(): Debug
    local self: Debug = setmetatable({}, { __index = Debug })
    self.draw_hitboxes = false
    self.log_scene_perf = false
    return self
end

global type PlayerSelectionMethod = enum
   "on"
   "off"
   "keep"
end

global type Map = enum
   "football"
   "factory"
end

local record Settings
    number_of_players: integer
    player_selection: PlayerSelectionMethod
    map: Map
    game_rules: GameRules
    debug: Debug
end

function Settings.new(): Settings
    local self: Settings = setmetatable({}, { __index = Settings })
    self.number_of_players = 4
    self.player_selection = "on"
    self.map = "football"
    self.game_rules = GameRules.new()
    self.debug = Debug.new()
    return self
end

local settings = Settings.new()

function Settings.set_player_selection(value: PlayerSelectionMethod)
    settings.player_selection = value
end

function Settings.set_map(value: Map)
    settings.map = value
end

function Settings.set_draw_hitboxs(value: boolean)
    settings.debug.draw_hitboxes = value
end

function Settings.set_log_scene_perf(value: boolean)
    settings.debug.log_scene_perf = value
end

function Settings.set_number_of_players(value: integer)
    settings.number_of_players = value
end

function Settings.set_nbr_soft_blocks(value: integer)
    settings.game_rules.items.nbr_soft_blocks = value
end

function Settings.set_nbr_of_eggs(value: integer)
    settings.game_rules.dinos.nbr_of_eggs = value
end

function Settings.set_nbr_of_bombs(value: integer)
    settings.game_rules.items.nbr_of_items.bomb = value
end

function Settings.set_nbr_of_lightning_bombs(value: integer)
    settings.game_rules.items.nbr_of_items.lightning_bomb = value
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

function Settings.set_spawn_of_bombs(value: number)
    settings.game_rules.items.spawn_rates.bomb = value
end

function Settings.set_spawn_of_lightning_bombs(value: number)
    settings.game_rules.items.spawn_rates.lightning_bomb = value
end

function Settings.set_spawn_of_fire(value: number)
    settings.game_rules.items.spawn_rates.fire = value
end

function Settings.set_spawn_of_speed(value: number)
    settings.game_rules.items.spawn_rates.speed = value
end

function Settings.set_spawn_of_kick(value: number)
    settings.game_rules.items.spawn_rates.kick = value
end

function Settings.set_start_position_shuffle(value: boolean)
    settings.game_rules.players.start_position_shuffle = value
end

function Settings.set_mad_bombers(value: boolean)
    settings.game_rules.players.mad_bombers.enabled = value
end

function Settings.set_mad_bombers_after_sudden_death(value: boolean)
    settings.game_rules.players.mad_bombers.after_sudden_death = value
end

function Settings.clear_mad_bombers(is_suddent_death: boolean): boolean
    local mad_bombers = settings.game_rules.players.mad_bombers
	local clear_bombers = is_suddent_death and not mad_bombers.after_sudden_death
	return not mad_bombers.enabled or clear_bombers
end

function Settings.set_start_speed(value: integer)
    settings.game_rules.players.start_speed = value
end

function Settings.set_start_with_kick(value: boolean)
    settings.game_rules.players.start_with_kick = value
end

function Settings.set_start_with_bombs(value: integer)
    settings.game_rules.players.start_with_bombs = value
end

function Settings.set_start_with_lightning_bombs(value: integer)
    settings.game_rules.players.start_with_lightning_bombs = value
end

function Settings.set_start_with_fire(value: integer)
    settings.game_rules.players.start_with_fire = value
end

function Settings.set_nbr_battles(value: integer)
    settings.game_rules.timings.nbr_battles = value
end

function Settings.set_battle_time(value: number)
    settings.game_rules.timings.battle = value
end

function Settings.set_sudden_death_time(value: number)
    settings.game_rules.timings.sudden_death = value
end

function Settings.get_enabled_dinos(): {DinoColor}
    local enabled_dinos: {DinoColor} = {}

    for color, enabled in pairs(settings.game_rules.dinos.enabled) do
        if enabled then
            table.insert(enabled_dinos, color)
        end
    end

    return enabled_dinos
end

function Settings.set_dino_enabled(color: DinoColor): function(value: boolean)
    return function(value: boolean)
        settings.game_rules.dinos.enabled[color] = value
    end
end

function Settings.set_game_rules_default()
    settings.game_rules = GameRules.new()
end

function Settings.set_game_rules_kick_debug()
    settings.game_rules = GameRules.new()
    settings.game_rules.players.start_with_kick = true
    settings.game_rules.players.start_with_bombs = 10
    settings.game_rules.items.nbr_soft_blocks = 0
end

function Settings.set_game_rules_lightning_bomb_debug()
    settings.game_rules = GameRules.new()
    settings.game_rules.players.start_with_kick = true
    settings.game_rules.players.start_with_lightning_bombs = 1
    settings.game_rules.timings.sudden_death = 150
    settings.game_rules.items.nbr_soft_blocks = 5
    settings.game_rules.items.spawn_rates.lightning_bomb = 0.1
    settings.game_rules.items.nbr_of_items.lightning_bomb = 3
    settings.game_rules.items.nbr_of_items.bomb = 2
    settings.game_rules.items.nbr_of_items.fire = 0
    settings.game_rules.items.nbr_of_items.kick = 0
    settings.game_rules.items.nbr_of_items.speed = 0
    settings.game_rules.dinos.nbr_of_eggs = 0
end

function Settings.set_game_rules_insanity()
    settings.game_rules = GameRules.new()
    settings.game_rules.items.nbr_soft_blocks = 30
    settings.game_rules.timings.battle = 120
    settings.game_rules.timings.sudden_death = 100
    settings.game_rules.items.spawn_rates.speed = 0.3
    settings.game_rules.items.spawn_rates.bomb = 0.3
    settings.game_rules.items.spawn_rates.fire = 0.5
    settings.game_rules.items.spawn_rates.kick = 0.07
    settings.game_rules.players.mad_bombers.enabled = true
    settings.game_rules.players.mad_bombers.after_sudden_death = true
end

function Settings.set_debug_performance()
    settings.game_rules = GameRules.new()
    settings.game_rules.players.start_with_kick = true
    settings.game_rules.players.start_with_bombs = 10
    settings.game_rules.timings.sudden_death = 120
    settings.debug.log_scene_perf = true
end

return settings
