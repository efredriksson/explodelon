-- The trampoline bounce mechanic, shared by the real Battle and the scripted menu-preview battle.

local collision = require("engine.collision")
local points = require("engine.geometry.points")
local hitboxes = require("engine.hitboxes")
local grid = require("level_layout.grid")
local map_entities = require("level_layout.map_entities")
local players = require("players")

local type Entity = require("engine.entity")
local type Kinematic = require("kinematic")
local type Lookup = collision.Lookup
local type Player = players.Player
local type Point = points.Point
local type ReadableGroup = collision.ReadableGroup

local record Trampolines
    blocks_jump: ReadableGroup<Kinematic>
    pressure_blocks: ReadableGroup<Entity>
end

local trampolines = {Trampolines = Trampolines}

-- Must match dino_inputs' jump-landing check.
local function landing_is_free(
    landing_position: Point, blocks_jump: ReadableGroup<Kinematic>, lookup: Lookup
): boolean
    local landing_area = hitboxes.new_block(landing_position)
    local close_blocks = lookup:in_box_and_group(
        landing_area:expand(grid.TILE_SIZE), blocks_jump
    )
    for _, block in ipairs(close_blocks) do
        if landing_area:overlap(block:movementbox()) then
            return false
        end
    end
    return grid.area():contains(landing_area)
end

local function tile_has_trampoline(position: Point): boolean
    for _, trampoline in ipairs(map_entities.get_trampolines()) do
        if trampoline.position:equal(position) then
            return true
        end
    end
    return false
end

function trampolines.new(
    blocks_jump: ReadableGroup<Kinematic>, pressure_blocks: ReadableGroup<Entity>
): Trampolines
    local self: Trampolines = setmetatable({}, {__index = Trampolines})
    self.blocks_jump = blocks_jump
    self.pressure_blocks = pressure_blocks
    return self
end

function Trampolines:_resolve_bounce(player: Player, lookup: Lookup)
    local landed_on_pressure_blocks = lookup:in_box_and_group(
        player:movementbox(), self.pressure_blocks
    )
    if #landed_on_pressure_blocks > 0 then
        player:land_bounce()
        return
    end

    local can_land = landing_is_free(player.jump_target, self.blocks_jump, lookup)
    if can_land and tile_has_trampoline(player.jump_target) then
        player:bounce_off_trampoline()
    elseif can_land then
        player:land_bounce()
    elseif grid.outside_visible_area(player:movementbox()) then
        player:wrap_bounce()
    else
        player:bounce_to_next_tile()
    end
end

function Trampolines:update(player: Player, lookup: Lookup)
    if
        player.action == "walk" and tile_has_trampoline(grid.snap_to(player.position))
    then
        player:start_bounce(player.direction)
    elseif player:is_bouncing() and player.jump_trajectory:finished() then
        self:_resolve_bounce(player, lookup)
    end
end

return trampolines
