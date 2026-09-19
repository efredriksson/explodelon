local engine_settings = require("engine.settings")
local itertools = require("itertools")

local enum ItemType
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
    local self: TimingRules = setmetatable({}, {__index = TimingRules})
    self.nbr_battles = 3
    self.battle = 180
    self.sudden_death = 60
    return self
end

function TimingRules:equals(other: TimingRules): boolean
    return self.nbr_battles == other.nbr_battles
        and self.battle == other.battle
        and self.sudden_death == other.sudden_death
end

local record ItemRules
    nbr_soft_blocks: integer
    nbr_of_items: {ItemType: integer}
    spawn_rates: {ItemType: number}
end

function ItemRules.new(): ItemRules
    local self: ItemRules = setmetatable({}, {__index = ItemRules})
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

function ItemRules:equals(other: ItemRules): boolean
    return self.nbr_soft_blocks == other.nbr_soft_blocks
        and itertools.maps_equal(self.nbr_of_items, other.nbr_of_items)
        and itertools.maps_equal(self.spawn_rates, other.spawn_rates)
end

local record MadBombers
    enabled: boolean
    after_sudden_death: boolean
end

function MadBombers.new(): MadBombers
    local self: MadBombers = setmetatable({}, {__index = MadBombers})
    self.enabled = true
    self.after_sudden_death = false
    return self
end

function MadBombers:equals(other: MadBombers): boolean
    return self.enabled == other.enabled
        and self.after_sudden_death == other.after_sudden_death
end

local record PlayerRules
    start_position_shuffle: boolean
    mad_bombers: MadBombers
    start_speed: integer
    start_with_kick: boolean
    start_with_bombs: integer
    start_with_lightning_bombs: integer
    start_with_fire: integer
    max_hp: integer
    petrify_grace_seconds: number
    petrify_stone_seconds: number
end

function PlayerRules.new(): PlayerRules
    local self: PlayerRules = setmetatable({}, {__index = PlayerRules})
    self.start_position_shuffle = true
    self.mad_bombers = MadBombers.new()
    self.start_speed = 60
    self.start_with_kick = false
    self.start_with_bombs = 1
    self.start_with_lightning_bombs = 0
    self.start_with_fire = 2
    self.max_hp = 100
    self.petrify_grace_seconds = 8
    self.petrify_stone_seconds = 5
    return self
end

function PlayerRules:equals(other: PlayerRules): boolean
    return self.start_position_shuffle == other.start_position_shuffle
        and self.mad_bombers:equals(other.mad_bombers)
        and self.start_speed == other.start_speed
        and self.start_with_kick == other.start_with_kick
        and self.start_with_bombs == other.start_with_bombs
        and self.start_with_lightning_bombs == other.start_with_lightning_bombs
        and self.start_with_fire == other.start_with_fire
        and self.max_hp == other.max_hp
        and self.petrify_grace_seconds == other.petrify_grace_seconds
        and self.petrify_stone_seconds == other.petrify_stone_seconds
end

local type DinoColor = enum
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
    local self: DinoRules = setmetatable({}, {__index = DinoRules})
    local enabled <total>: {DinoColor: boolean} = {
        blue = true,
        pink = true,
        purple = true,
        green = true,
        yellow = true,
    }

    self.nbr_of_eggs = 4
    self.enabled = enabled
    return self
end

function DinoRules:equals(other: DinoRules): boolean
    return self.nbr_of_eggs == other.nbr_of_eggs
        and itertools.maps_equal(self.enabled, other.enabled)
end

local record IceRules
    acceleration_factor: number
    friction_factor: number
end

function IceRules.new(): IceRules
    local self: IceRules = setmetatable({}, {__index = IceRules})
    self.acceleration_factor = 4
    self.friction_factor = 1
    return self
end

function IceRules:equals(other: IceRules): boolean
    return self.acceleration_factor == other.acceleration_factor
        and self.friction_factor == other.friction_factor
end

local record GameRules
    players: PlayerRules
    items: ItemRules
    timings: TimingRules
    dinos: DinoRules
    ice: IceRules
end

function GameRules.new(): GameRules
    local self: GameRules = setmetatable({}, {__index = GameRules})
    self.players = PlayerRules.new()
    self.items = ItemRules.new()
    self.timings = TimingRules.new()
    self.dinos = DinoRules.new()
    self.ice = IceRules.new()
    return self
end

function GameRules:equals(other: GameRules): boolean
    return self.players:equals(other.players)
        and self.items:equals(other.items)
        and self.timings:equals(other.timings)
        and self.dinos:equals(other.dinos)
        and self.ice:equals(other.ice)
end

local type Map = enum
    "football"
    "factory"
    "ice_rink"
    "bouncing"
end

local type BlockPattern = enum
    "grid"
    "empty"
    "quadrant"
end

local type FallPattern = enum
    "left_right"
    "top_bottom"
end

local record MapPatternSettings
    block_pattern: BlockPattern
    fall_pattern: FallPattern
end

function MapPatternSettings.new(
    block_pattern: BlockPattern, fall_pattern: FallPattern
): MapPatternSettings
    local self: MapPatternSettings = setmetatable({}, {__index = MapPatternSettings})
    self.block_pattern = block_pattern
    self.fall_pattern = fall_pattern
    return self
end

local function get_default_map_patterns(): {Map: MapPatternSettings}
    local default_map_patterns <total>: {Map: MapPatternSettings} = {
        football = MapPatternSettings.new("grid", "top_bottom"),
        factory = MapPatternSettings.new("grid", "left_right"),
        ice_rink = MapPatternSettings.new("quadrant", "left_right"),
        bouncing = MapPatternSettings.new("grid", "left_right"),
    }
    return default_map_patterns
end

-- Debug rules are off this list; they have no player-facing name.
local type RulesetName = enum
    "default"
    "insanity"
    "bomb_stack"
    "dino_madness"
end

local type DebugRulesetName = enum
    "kick"
    "lightning_bomb"
    "performance"
    "dinos"
end

local record Settings
    MINIMUM_PLAYERS: integer
    number_of_auto_selected_characters: integer
    auto_select_characters: boolean
    skip_options_screen: boolean
    teams: boolean
    map: Map
    ruleset: RulesetName
    game_rules: GameRules
    untweaked_rules: GameRules
    kept_rules: GameRules
    kept_ruleset: RulesetName
    map_patterns: {Map: MapPatternSettings}
    -- Type export
    ItemType: ItemType
    DinoColor: DinoColor
    GameRules: GameRules
    Map: Map
    RulesetName: RulesetName
    DebugRulesetName: DebugRulesetName
    BlockPattern: BlockPattern
    FallPattern: FallPattern
end

local function new_default_rules(): GameRules
    return GameRules.new()
end

function Settings.new(): Settings
    local self: Settings = setmetatable({}, {__index = Settings})
    self.MINIMUM_PLAYERS = 2
    self.number_of_auto_selected_characters = 4
    self.auto_select_characters = false
    self.teams = false
    self.map = "football"
    self.ruleset = "default"
    self.skip_options_screen = false
    self.game_rules = GameRules.new()
    self.untweaked_rules = new_default_rules()
    self.kept_rules = nil
    self.kept_ruleset = nil
    self.map_patterns = get_default_map_patterns()
    -- Type export
    self.ItemType = ItemType
    self.DinoColor = DinoColor
    self.GameRules = GameRules
    self.Map = Map
    self.RulesetName = RulesetName
    self.DebugRulesetName = DebugRulesetName
    self.BlockPattern = BlockPattern
    self.FallPattern = FallPattern
    return self
end

local settings = Settings.new()

function Settings.set_auto_select_characters(value: boolean)
    settings.auto_select_characters = value
end

function Settings.set_skip_options_screen(value: boolean)
    settings.skip_options_screen = value
end

function Settings.set_map(value: Map)
    settings.map = value
end

function Settings.set_block_pattern(value: BlockPattern)
    settings.map_patterns[settings.map].block_pattern = value
end

function Settings.get_block_pattern(): BlockPattern
    return settings.map_patterns[settings.map].block_pattern
end

function Settings.set_fall_pattern(value: FallPattern)
    settings.map_patterns[settings.map].fall_pattern = value
end

function Settings.get_fall_pattern(): FallPattern
    return settings.map_patterns[settings.map].fall_pattern
end

function Settings.default_block_pattern(map: Map): BlockPattern
    return get_default_map_patterns()[map].block_pattern
end

function Settings.set_number_of_auto_selected_characters(value: integer)
    settings.number_of_auto_selected_characters = value
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

function Settings.set_petrify_grace_seconds(value: number)
    settings.game_rules.players.petrify_grace_seconds = value
end

function Settings.set_petrify_stone_seconds(value: number)
    settings.game_rules.players.petrify_stone_seconds = value
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

function Settings.set_max_hp(value: integer)
    settings.game_rules.players.max_hp = value
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
    return function(value: boolean) settings.game_rules.dinos.enabled[color] = value end
end

function Settings.set_teams(value: boolean)
    settings.teams = value
end

function Settings.set_ice_acceleration_factor(value: number)
    settings.game_rules.ice.acceleration_factor = value
end

function Settings.set_ice_friction_factor(value: number)
    settings.game_rules.ice.friction_factor = value
end

local function new_insanity_rules(): GameRules
    local rules = GameRules.new()
    rules.items.nbr_soft_blocks = 30
    rules.timings.battle = 120
    rules.timings.sudden_death = 100
    rules.items.spawn_rates.speed = 0.3
    rules.items.spawn_rates.bomb = 0.3
    rules.items.spawn_rates.fire = 0.5
    rules.items.spawn_rates.kick = 0.07
    rules.players.mad_bombers.enabled = true
    rules.players.mad_bombers.after_sudden_death = true
    return rules
end

local function new_bomb_stack_rules(): GameRules
    local rules = GameRules.new()
    rules.items.nbr_soft_blocks = 65
    rules.items.nbr_of_items.bomb = 12
    rules.items.nbr_of_items.fire = 6
    rules.items.nbr_of_items.speed = 0
    rules.items.nbr_of_items.kick = 0
    rules.items.nbr_of_items.lightning_bomb = 2
    rules.items.spawn_rates.bomb = 0.1
    rules.items.spawn_rates.speed = 0.1
    rules.dinos.nbr_of_eggs = 6
    rules.dinos.enabled.pink = false
    rules.dinos.enabled.green = false
    rules.dinos.enabled.purple = false
    rules.timings.battle = 150
    rules.timings.sudden_death = 70
    rules.players.mad_bombers.enabled = true
    rules.players.mad_bombers.after_sudden_death = false
    return rules
end

local function new_dino_madness_rules(): GameRules
    local rules = GameRules.new()
    rules.items.nbr_soft_blocks = 60
    rules.timings.battle = 150
    rules.timings.sudden_death = 90
    rules.dinos.nbr_of_eggs = 15
    rules.items.spawn_rates.lightning_bomb = 0.08
    rules.items.spawn_rates.bomb = 0.16
    rules.items.spawn_rates.speed = 0.1
    return rules
end

local RULESET_BUILDERS <total>: {RulesetName: function(): GameRules} = {
    default = new_default_rules,
    insanity = new_insanity_rules,
    bomb_stack = new_bomb_stack_rules,
    dino_madness = new_dino_madness_rules,
}

function Settings.build_ruleset(name: RulesetName): GameRules
    return RULESET_BUILDERS[name]()
end

function Settings.has_tweaked_rules(): boolean
    return not settings.game_rules:equals(settings.untweaked_rules)
end

local function set_rules_aside()
    settings.kept_rules = settings.game_rules
    settings.kept_ruleset = settings.ruleset
end

local function forget_rules_set_aside()
    settings.kept_rules = nil
    settings.kept_ruleset = nil
end

function Settings.set_ruleset(name: RulesetName)
    if Settings.has_tweaked_rules() then
        set_rules_aside()
    end

    settings.game_rules = Settings.build_ruleset(name)
    settings.untweaked_rules = Settings.build_ruleset(name)
    settings.ruleset = name
end

-- The players' own rules are either the ones being played or the ones set
-- aside, so the questions below are the only way to ask about them. Where they
-- are being kept is nobody else's business.
function Settings.has_house_rules(): boolean
    return settings.kept_rules ~= nil or Settings.has_tweaked_rules()
end

function Settings.playing_house_rules(): boolean
    return settings.kept_rules == nil
end

function Settings.house_rules(): GameRules
    return settings.kept_rules or settings.game_rules
end

function Settings.house_ruleset(): RulesetName
    return settings.kept_ruleset or settings.ruleset
end

function Settings.tweaking_replaces_house_rules(): boolean
    return settings.kept_rules ~= nil and not Settings.has_tweaked_rules()
end

-- Nothing to bring back when they are already being played, and the store
-- empties as they return, so they are never in both places at once.
function Settings.play_house_rules()
    if settings.kept_rules == nil then
        return
    end
    settings.untweaked_rules = Settings.build_ruleset(settings.kept_ruleset)
    settings.game_rules = settings.kept_rules
    settings.ruleset = settings.kept_ruleset
    forget_rules_set_aside()
end

-- There is only room for one set of house rules, so editing the rules in play
-- is what throws away the ones set aside.
function Settings.finish_tweaking()
    if Settings.has_tweaked_rules() then
        forget_rules_set_aside()
    end
end

local function new_debug_kick_rules(): GameRules
    local rules = GameRules.new()
    rules.players.start_with_kick = true
    rules.players.start_with_bombs = 10
    rules.items.nbr_soft_blocks = 0
    return rules
end

local function new_debug_lightning_bomb_rules(): GameRules
    local rules = GameRules.new()
    rules.players.start_with_kick = true
    rules.players.start_with_lightning_bombs = 1
    rules.timings.sudden_death = 150
    rules.items.nbr_soft_blocks = 5
    rules.items.spawn_rates.lightning_bomb = 0.1
    rules.items.nbr_of_items.lightning_bomb = 3
    rules.items.nbr_of_items.bomb = 2
    rules.items.nbr_of_items.fire = 0
    rules.items.nbr_of_items.kick = 0
    rules.items.nbr_of_items.speed = 0
    rules.dinos.nbr_of_eggs = 0
    return rules
end

local function new_debug_performance_rules(): GameRules
    local rules = GameRules.new()
    rules.players.start_with_kick = true
    rules.players.start_with_bombs = 10
    rules.timings.sudden_death = 120
    return rules
end

local function new_debug_dinos_rules(): GameRules
    local rules = GameRules.new()
    rules.items.nbr_of_items.fire = 0
    rules.items.nbr_of_items.kick = 0
    rules.items.nbr_of_items.bomb = 0
    rules.items.nbr_of_items.speed = 0
    rules.items.nbr_soft_blocks = 20
    rules.dinos.nbr_of_eggs = 20
    rules.dinos.enabled.blue = false
    rules.dinos.enabled.pink = false
    rules.dinos.enabled.purple = true
    rules.dinos.enabled.green = false
    rules.dinos.enabled.yellow = false
    return rules
end

local DEBUG_RULESET_BUILDERS <total>: {DebugRulesetName: function(): GameRules} = {
    kick = new_debug_kick_rules,
    lightning_bomb = new_debug_lightning_bomb_rules,
    performance = new_debug_performance_rules,
    dinos = new_debug_dinos_rules,
}

function Settings.set_debug_ruleset(name: DebugRulesetName)
    Settings.set_ruleset("default")
    settings.game_rules = DEBUG_RULESET_BUILDERS[name]()
    settings.untweaked_rules = DEBUG_RULESET_BUILDERS[name]()
    engine_settings.set_log_scene_perf(true)
    settings.auto_select_characters = true
    settings.skip_options_screen = true
end

return settings
