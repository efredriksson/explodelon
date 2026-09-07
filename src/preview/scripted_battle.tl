-- Runs the real battle systems over a choreography, on a loop.

local bombs = require("bombs.bombs")
local lightning_bombs = require("bombs.lightning_bombs")
local collision = require("engine.collision")
local vectors = require("engine.geometry.vectors")
local hard_blocks = require("hard_blocks")
local items = require("items")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local maps = require("level_layout.maps.init")
local movement = require("movement")
local player_animations = require("player_animations")
local players = require("players")
local choreography = require("preview.choreography")
local scenery = require("preview.scenery")
local settings = require("settings")
local soft_blocks = require("soft_blocks")
local trampolines = require("trampolines")
local z_index = require("z_index")

local type Bombs = bombs.Bombs
local type Choreography = choreography.Choreography
local type CombinedGroup = collision.CombinedGroup
local type Direction = vectors.Direction
local type Entity = require("engine.entity")
local type Explodable = require("bombs.explodable")
local type Group = collision.Group
local type HardBlocks = hard_blocks.HardBlocks
local type Items = items.Items
local type Kinematic = require("kinematic")
local type LightningBombs = lightning_bombs.LightningBombs
local type Map = settings.Map
local type Player = players.Player
local type PlayerAnimations = player_animations.PlayerAnimations
local type Scenery = scenery.Scenery
local type SoftBlocks = soft_blocks.SoftBlocks
local type Stage = choreography.Stage
local type Trampolines = trampolines.Trampolines
local type Vector = vectors.Vector

local STABLE_STEP_SECONDS = 1 / 60
local STABLE_MAX_CATCHUP_SECONDS = STABLE_STEP_SECONDS * 2

-- A clock that will keep to a more uniform 'dt', reducing the amount of numerical
-- rounding issues. This helps ensure the map previews are deterministic.
local record StableClock
    pending: number
end

function StableClock.new(): StableClock
    local self: StableClock = setmetatable({}, {__index = StableClock})
    self.pending = 0
    return self
end

function StableClock:tick(dt: number): number
    local number_of_steps = 0

    self.pending = math.min(self.pending + dt, STABLE_MAX_CATCHUP_SECONDS)
    while self.pending >= STABLE_STEP_SECONDS do
        self.pending = self.pending - STABLE_STEP_SECONDS
        number_of_steps = number_of_steps + 1
    end

    return STABLE_STEP_SECONDS * number_of_steps
end

local record ScriptedBattle is Stage
    scenery: Scenery
    choreography: Choreography
    entered_map: Map
    ice_sliding: boolean
    clock: StableClock
    elapsed: number

    players: {Player}
    player_inputs: {Player: {Direction}}

    hard_blocks: HardBlocks
    soft_blocks: SoftBlocks
    items: Items
    lightning_bombs: LightningBombs
    bombs: Bombs
    player_animations: PlayerAnimations

    alive_players_group: Group<Player>
    blockers: CombinedGroup<Explodable>
    blocks_bombs: CombinedGroup<Kinematic>
    blocks_jump: CombinedGroup<Kinematic>
    empty_bounce_group: Group<Kinematic>
    empty_pressure_blocks: Group<Entity>
    explodables: CombinedGroup<Explodable>
    trampolines: Trampolines
end

local scripted_battle = {
    ScriptedBattle = ScriptedBattle,
}

local function is_alive(player: Player): boolean
    return player:is_alive()
end

function ScriptedBattle:_rebuild_groups()
    self.blockers = collision.new_combined_group(
        self.hard_blocks.on_ground.set, self.soft_blocks.on_ground.set
    )
    -- Scenery pops on camera; a battle handles soft blocks elsewhere.
    self.explodables = collision.new_combined_group(
        self.alive_players_group.set,
        self.soft_blocks.on_ground.set,
        self.bombs.on_ground.set
    )
    self.blocks_jump = collision.new_combined_group(
        self.hard_blocks.on_ground.set,
        self.soft_blocks.on_ground.set,
        self.bombs.on_ground.set
    )
end

function ScriptedBattle:_restart()
    self.players = self.choreography:open(self)
    self.player_inputs = {}
    self.elapsed = 0

    self.soft_blocks = soft_blocks.new(self.scenery.soft_blocks)
    self.items = items.new()
    for _, drop in ipairs(self.scenery.items) do
        self.items:drop_at(drop.at, drop.kind)
    end
    self.bombs = bombs.new(true)
    self:_rebuild_groups()
    self.trampolines = trampolines.new(self.blocks_jump, self.empty_pressure_blocks)
    self.player_animations = player_animations.new(self.players)
end

function ScriptedBattle:_stand_up_map()
    local map = self.scenery.map
    -- bombs:update reads goals and layout off the global settings.map; leave()
    -- puts it back.
    settings.set_map(map)
    self.ice_sliding = maps.get_layout():has_ice()
    self.hard_blocks = hard_blocks.new(map_entities.get_block_configs({}).hard)
    -- Hard blocks only, unlike Battle:load, so drones and kicked bombs pass
    -- through scenery: a piece may stand blocks anywhere off a blast path.
    self.blocks_bombs = collision.new_combined_group(self.hard_blocks.on_ground.set)
end

function ScriptedBattle:play(stage_set: Scenery, piece: Choreography)
    self.scenery = stage_set
    self.choreography = piece
    self:_stand_up_map()
    self:_restart()
end

function scripted_battle.new(stage_set: Scenery, piece: Choreography): ScriptedBattle
    local self: ScriptedBattle = setmetatable({}, {__index = ScriptedBattle})
    self.entered_map = settings.map
    self.clock = StableClock.new()
    self.lightning_bombs = lightning_bombs.new()
    self.alive_players_group = collision.new_group()
    self.empty_bounce_group = collision.new_group()
    self.empty_pressure_blocks = collision.new_group()

    self:play(stage_set, piece)
    return self
end

function ScriptedBattle:leave()
    settings.set_map(self.entered_map)
end

function ScriptedBattle:place_bomb(player: Player)
    self.bombs:place_bomb(player, itertools.sets_as_list(self.bombs.on_ground.set))
end

function ScriptedBattle:set_player_inputs(player: Player, directions: {Direction})
    self.player_inputs[player] = directions
end

function ScriptedBattle:face(player: Player, direction: Direction)
    player.direction = direction
end

function ScriptedBattle:slide(player: Player, velocity: Vector)
    player.ice_velocity = velocity
end

function ScriptedBattle:_step_systems(dt: number)
    local alive_players = itertools.filter(self.players, is_alive)
    self.alive_players_group:rebuild(alive_players)
    local lookup = collision.new_lookup(
        self.hard_blocks.on_ground.set,
        self.soft_blocks.on_ground.set,
        self.bombs.on_ground.set,
        self.alive_players_group.set
    )

    self.bombs:update(
        dt,
        self.blockers,
        self.explodables,
        self.blocks_bombs,
        self.alive_players_group,
        self.bombs.on_ground,
        self.empty_bounce_group,
        lookup
    )

    for _, player in ipairs(alive_players) do
        player:update(dt)
        if player:accepts_input() then
            local close_blocks = lookup:in_box_and_group(
                player:movementbox():expand(grid.TILE_SIZE / 2), self.blocks_bombs
            )
            movement.set_position_and_dir_scripted(
                player,
                dt,
                self.player_inputs[player] or {},
                close_blocks,
                self.lightning_bombs,
                self.blocks_bombs,
                self.alive_players_group,
                self.bombs.on_ground,
                lookup,
                self.ice_sliding
            )
        end
        self.trampolines:update(player, lookup)
    end

    self.soft_blocks:update(dt)
    self.items:update(dt)
    self.player_animations:update(dt)
end

function ScriptedBattle:_update(dt: number)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= self.choreography.cycle_length then
        self:_restart()
        return
    end

    self.choreography:step(dt)
    self:_step_systems(dt)
end

function ScriptedBattle:update(dt: number)
    self:_update(self.clock:tick(dt))
end

function ScriptedBattle:draw()
    self.bombs:draw_on_ground_shadows()
    self.bombs.explosions:draw()

    local entities: {Entity} = itertools.sets_as_list(
        self.hard_blocks.on_ground.set,
        self.soft_blocks.on_ground.set,
        self.items.on_ground.set,
        self.bombs.on_ground.set,
        self.player_animations:get_all()
    )
    table.sort(entities, z_index.back_to_front)
    for _, entity in ipairs(entities) do
        entity:draw()
    end
end

return scripted_battle
