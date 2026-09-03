-- Runs the real battle systems over a flat list of scripted players given some player input.

local bombs = require("bombs.bombs")
local lightning_bombs = require("bombs.lightning_bombs")
local collision = require("engine.collision")
local points = require("engine.geometry.points")
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
local settings = require("settings")
local soft_blocks = require("soft_blocks")
local trampolines = require("trampolines")
local z_index = require("z_index")

local type Bombs = bombs.Bombs
local type CombinedGroup = collision.CombinedGroup
local type Direction = vectors.Direction
local type Entity = require("engine.entity")
local type Explodable = require("bombs.explodable")
local type Group = collision.Group
local type HardBlocks = hard_blocks.HardBlocks
local type ItemType = settings.ItemType
local type Items = items.Items
local type Kinematic = require("kinematic")
local type LightningBombs = lightning_bombs.LightningBombs
local type Map = settings.Map
local type Player = players.Player
local type PlayerAnimations = player_animations.PlayerAnimations
local type Point = points.Point
local type SoftBlockConfig = map_entities.SoftBlockConfig
local type SoftBlocks = soft_blocks.SoftBlocks
local type Trampolines = trampolines.Trampolines

local record ItemDrop
    at: Point
    kind: ItemType
end

function ItemDrop.new(at: Point, kind: ItemType): ItemDrop
    local self: ItemDrop = setmetatable({}, {__index = ItemDrop})
    self.at = at
    self.kind = kind
    return self
end

local record WorldConfig
    map: Map
    scenery_soft_blocks: {SoftBlockConfig}
    scenery_items: {ItemDrop}
end

function WorldConfig.new(
    map: Map, scenery_soft_blocks: {SoftBlockConfig}, scenery_items: {ItemDrop}
): WorldConfig
    local self: WorldConfig = setmetatable({}, {__index = WorldConfig})
    self.map = map
    self.scenery_soft_blocks = scenery_soft_blocks
    self.scenery_items = scenery_items
    return self
end

local record ScriptedBattle
    config: WorldConfig
    entered_map: Map
    ice_sliding: boolean

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
    WorldConfig = WorldConfig,
    ScriptedBattle = ScriptedBattle,
}

function scripted_battle.soft_block_at(column: integer, row: integer): SoftBlockConfig
    return map_entities.SoftBlockConfig.new(
        grid.get_tile_position(column, row), nil, false
    )
end

function scripted_battle.item_at(
    column: integer, row: integer, kind: ItemType
): ItemDrop
    return ItemDrop.new(grid.get_tile_position(column, row), kind)
end

local function is_alive(player: Player): boolean
    return player:is_alive()
end

-- A reset makes new soft_blocks/bombs sets, so the groups built over them here rebuild too.
function ScriptedBattle:reset(scripted_players: {Player})
    self.players = scripted_players
    self.player_inputs = {}

    self.soft_blocks = soft_blocks.new(self.config.scenery_soft_blocks)
    self.items = items.new()
    for _, drop in ipairs(self.config.scenery_items) do
        self.items:drop_at(drop.at, drop.kind)
    end
    self.bombs = bombs.new(true)
    self.blockers = collision.new_combined_group(
        self.hard_blocks.on_ground.set, self.soft_blocks.on_ground.set
    )
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
    self.trampolines = trampolines.new(self.blocks_jump, self.empty_pressure_blocks)
    self.player_animations = player_animations.new(self.players)
end

function scripted_battle.new(
    config: WorldConfig, scripted_players: {Player}
): ScriptedBattle
    local self: ScriptedBattle = setmetatable({}, {__index = ScriptedBattle})
    self.config = config
    self.entered_map = settings.map
    -- bombs:update reads goal tiles and block layout off the global settings.map,
    -- so we hold it here until leave() restores the previous map.
    settings.set_map(config.map)
    self.ice_sliding = maps.get_layout():has_ice()

    self.hard_blocks = hard_blocks.new(map_entities.get_block_configs({}).hard)
    self.lightning_bombs = lightning_bombs.new()
    self.alive_players_group = collision.new_group()
    self.blocks_bombs = collision.new_combined_group(self.hard_blocks.on_ground.set)
    self.empty_bounce_group = collision.new_group()
    self.empty_pressure_blocks = collision.new_group()

    self:reset(scripted_players)
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

function ScriptedBattle:update(dt: number)
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
