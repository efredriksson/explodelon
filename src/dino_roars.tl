-- Battle logic for what a stun cry or sonic blast hits.

local bombs = require("bombs.bombs")
local collision = require("engine.collision")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local players = require("players")
local soft_blocks = require("soft_blocks")

local type Bomb = bombs.Bomb
local type Lookup = collision.Lookup
local type Player = players.Player
local type ReadableGroup = collision.ReadableGroup
local type SoftBlock = soft_blocks.SoftBlock

local record DinoRoars
    alive_players: ReadableGroup<Player>
    bombs: ReadableGroup<Bomb>
    soft_blocks: ReadableGroup<SoftBlock>
end

local dino_roars = {DinoRoars = DinoRoars}

function dino_roars.new(
    alive_players: ReadableGroup<Player>,
    bombs_group: ReadableGroup<Bomb>,
    soft_blocks_group: ReadableGroup<SoftBlock>
): DinoRoars
    local self: DinoRoars = setmetatable({}, {__index = DinoRoars})
    self.alive_players = alive_players
    self.bombs = bombs_group
    self.soft_blocks = soft_blocks_group
    return self
end

function DinoRoars:_resolve_stun_cry(lookup: Lookup, player: Player)
    local cry = player:get_stun_cry_hitbox()
    local function is_nearest_to_a_reached_tile(other: Player): boolean
        return cry:contains(grid.nearest_tile(other.position))
    end
    local hit_players = itertools.filter(
        lookup:in_box_and_group(cry, self.alive_players), is_nearest_to_a_reached_tile
    )
    for _, hit_player in ipairs(hit_players) do
        hit_player:hit_with_roar()
    end
end

function DinoRoars:_resolve_sonic_blast(lookup: Lookup, player: Player)
    local hit_bombs = lookup:in_box_and_group(
        player:get_sonic_blast_hitbox(), self.bombs
    )
    for _, hit_bomb in ipairs(hit_bombs) do
        hit_bomb:blow_up(1.0)
    end

    local hit_blocks = lookup:in_box_and_group(
        player:get_sonic_blast_hitbox(), self.soft_blocks
    )
    for _, hit_block in ipairs(hit_blocks) do
        hit_block:reveal()
    end
end

function DinoRoars:resolve(lookup: Lookup, player: Player)
    if player:is_stun_crying() then
        self:_resolve_stun_cry(lookup, player)
    end
    if player:is_sonic_blasting() then
        self:_resolve_sonic_blast(lookup, player)
    end
end

return dino_roars
