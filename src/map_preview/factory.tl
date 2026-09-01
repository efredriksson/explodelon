-- Looping factory-map menu preview: scripted drones run the real battle systems.

local bombs = require("bombs.bombs")
local lightning_bombs = require("bombs.lightning_bombs")
local characters = require("characters")
local collision = require("engine.collision")
local vectors = require("engine.geometry.vectors")
local hard_blocks = require("hard_blocks")
local items = require("items")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local movement = require("movement")
local player_animations = require("player_animations")
local players = require("players")
local settings = require("settings")
local soft_blocks = require("soft_blocks")
local z_index = require("z_index")

local type Bombs = bombs.Bombs
local type CharacterName = characters.CharacterName
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
local type MapPreview = require("map_preview.interfaces")
local type Player = players.Player
local type PlayerAnimations = player_animations.PlayerAnimations
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type SoftBlocks = soft_blocks.SoftBlocks

local KICKER_SPRITE: CharacterName = "kotetsu"
local VICTIM_SPRITE: CharacterName = "white"

-- Row 2 has no hard blocks, so the kicker moves freely there and its kicked
-- bombs slide left into the conveyor ring the victim is trapped in.
local KICKER_START = grid.get_tile_position(14, 2)
local VICTIM_START = grid.get_tile_position(8, 5)

local KICK_COUNT = 4
-- Wider than default so ring-edge detonations reach the victim at the centre.
local KICKER_FIRE_RANGE = 4
local STEP_OFF_DISTANCE = 20
local RETURN_MARGIN = 1.75
local REST_DURATION = 0.15
-- After the last kick the kicker backs off so the chain reaction spares it.
local RETREAT_DISTANCE = 32

local PACE_RANGE = 16

-- Old enough to die outright rather than petrify.
local VICTIM_STARTS_AGED = 999

local CYCLE_LENGTH = 4.4

local function soft_block_at(column: integer, row: integer): SoftBlockConfig
    return map_entities.SoftBlockConfig.new(
        grid.get_tile_position(column, row), nil, false
    )
end

-- Backdrop clutter for the corners, plus a few beside the conveyor ring close
-- enough for the chain reaction to blow apart. None sit on a bomb's path.
local SCENERY_SOFT_BLOCKS: {SoftBlockConfig} = {
    soft_block_at(0, 9),
    soft_block_at(0, 10),
    soft_block_at(1, 10),
    soft_block_at(2, 10),
    soft_block_at(3, 2),
    soft_block_at(3, 4),
    soft_block_at(3, 8),
    soft_block_at(3, 10),
    soft_block_at(4, 9),
    soft_block_at(5, 10),
    soft_block_at(11, 10),
    soft_block_at(12, 9),
    soft_block_at(13, 8),
    soft_block_at(13, 10),
    soft_block_at(14, 10),
    soft_block_at(15, 10),
    soft_block_at(16, 9),
    soft_block_at(16, 10),
}

local function place_scenery_items(items_: Items)
    items_:drop_at(grid.get_tile_position(2, 9), "fire")
    items_:drop_at(grid.get_tile_position(14, 9), "speed")
    -- A kick pickup under the kicker, hinting at the ability the drone shows off.
    items_:drop_at(grid.get_tile_position(14, 3), "kick")
end

local type KickerPhase = enum
    "placing"
    "stepping_off"
    "returning"
    "retreating"
    "resting"
end

local type VictimPhase = enum
    "pacing_down"
    "pacing_up"
end

local record FactoryPreview is MapPreview
    entered_map: Map
    elapsed: number

    hard_blocks: HardBlocks
    soft_blocks: SoftBlocks
    items: Items
    lightning_bombs: LightningBombs
    bombs: Bombs
    players: {Player}
    kicker: Player
    victim: Player
    player_animations: PlayerAnimations

    alive_players_group: Group<Player>
    blockers: CombinedGroup<Explodable>
    blocks_bombs: CombinedGroup<Kinematic>
    empty_bounce_group: Group<Kinematic>
    explodables: CombinedGroup<Explodable>

    kicker_phase: KickerPhase
    kicker_rest_for: number
    kicker_hold: {Direction}
    bombs_placed: integer

    victim_phase: VictimPhase
    victim_hold: {Direction}
end

local factory = {}

local function is_alive(player: Player): boolean
    return player:is_alive()
end

function FactoryPreview:_restart()
    self.elapsed = 0
    self.players = {
        players.new(1, KICKER_SPRITE, KICKER_START),
        players.new(2, VICTIM_SPRITE, VICTIM_START),
    }
    self.kicker = self.players[1]
    self.victim = self.players[2]
    self.kicker.has_kick = true
    self.kicker.bombs = KICK_COUNT
    self.kicker.fire = KICKER_FIRE_RANGE
    self.victim.time_alive = VICTIM_STARTS_AGED

    self.alive_players_group:rebuild(self.players)
    self.soft_blocks = soft_blocks.new(SCENERY_SOFT_BLOCKS)
    self.bombs = bombs.new(true)
    self.blockers = collision.new_combined_group(
        self.hard_blocks.on_ground.set, self.soft_blocks.on_ground.set
    )
    self.explodables = collision.new_combined_group(
        self.alive_players_group.set,
        self.soft_blocks.on_ground.set,
        self.bombs.on_ground.set
    )
    self.player_animations = player_animations.new(self.players)

    self.kicker_phase = "placing"
    self.kicker_rest_for = 0
    self.kicker_hold = {}
    self.bombs_placed = 0

    self.victim_phase = "pacing_down"
    self.victim_hold = {}
end

function factory.new(): FactoryPreview
    local self: FactoryPreview = setmetatable({}, {__index = FactoryPreview})
    self.entered_map = settings.map
    settings.set_map("factory")

    self.hard_blocks = hard_blocks.new(map_entities.get_block_configs({}).hard)
    self.items = items.new()
    place_scenery_items(self.items)
    self.lightning_bombs = lightning_bombs.new()
    self.alive_players_group = collision.new_group()
    self.blocks_bombs = collision.new_combined_group(self.hard_blocks.on_ground.set)
    self.empty_bounce_group = collision.new_group()

    self:_restart()
    return self
end

function FactoryPreview:leave()
    settings.set_map(self.entered_map)
end

function FactoryPreview:_advance_kicker(dt: number)
    if self.kicker_phase == "placing" then
        local placed: {Entity} = itertools.sets_as_list(self.bombs.on_ground.set)
        self.bombs:place_bomb(self.kicker, placed)
        self.bombs_placed = self.bombs_placed + 1
        self.kicker_hold = {}
        self.kicker_phase = "stepping_off"
        return
    end

    if self.kicker_phase == "stepping_off" then
        self.kicker_hold = {"right"}
        if self.kicker.position:distance_to(KICKER_START) >= STEP_OFF_DISTANCE then
            self.kicker_phase = "returning"
        end
        return
    end

    if self.kicker_phase == "returning" then
        self.kicker_hold = {"left"}
        if self.kicker.position:distance_to(KICKER_START) <= RETURN_MARGIN then
            if self.bombs_placed >= KICK_COUNT then
                self.kicker_phase = "retreating"
            else
                self.kicker_phase = "resting"
                self.kicker_rest_for = REST_DURATION
            end
        end
        return
    end

    if self.kicker_phase == "retreating" then
        self.kicker_hold = {"right"}
        if self.kicker.position:distance_to(KICKER_START) >= RETREAT_DISTANCE then
            self.kicker_phase = "resting"
        end
        return
    end

    if self.kicker_phase == "resting" then
        self.kicker_hold = {}
        self.kicker_rest_for = self.kicker_rest_for - dt
        if self.kicker_rest_for <= 0 and self.bombs_placed < KICK_COUNT then
            self.kicker_phase = "placing"
        end
    end
end

-- Hard pillars flank the ring's centre, so the victim can only pace up and down.
function FactoryPreview:_advance_victim()
    if not self.victim:is_alive() then
        self.victim_hold = {}
        return
    end

    if self.victim_phase == "pacing_down" then
        self.victim_hold = {"down"}
        if self.victim.position.y >= VICTIM_START.y + PACE_RANGE then
            self.victim_phase = "pacing_up"
        end
    else
        self.victim_hold = {"up"}
        if self.victim.position.y <= VICTIM_START.y - PACE_RANGE then
            self.victim_phase = "pacing_down"
        end
    end
end

function FactoryPreview:_held_for(player: Player): {Direction}
    if player == self.kicker then
        return self.kicker_hold
    end
    return self.victim_hold
end

function FactoryPreview:update(dt: number)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= CYCLE_LENGTH then
        self:_restart()
        return
    end

    self:_advance_kicker(dt)
    self:_advance_victim()

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
                self:_held_for(player),
                close_blocks,
                self.lightning_bombs,
                self.blocks_bombs,
                self.alive_players_group,
                self.bombs.on_ground,
                lookup
            )
        end
    end

    self.soft_blocks:update(dt)
    self.items:update(dt)
    self.player_animations:update(dt)
end

function FactoryPreview:draw()
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

return factory
