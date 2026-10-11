local bombs = require("bombs.bombs")
local closed_tiles = require("closed_tiles")
local collision = require("engine.collision")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local hitboxes = require("engine.hitboxes")
local joysticks = require("engine.joysticks")
local grid = require("level_layout.grid")
local players = require("players")

local type Bomb = bombs.Bomb
local type Bombs = bombs.Bombs
local type Kinematic = require("kinematic")
local type Player = players.Player
local type ReadableGroup = collision.ReadableGroup
local type Lookup = collision.Lookup
local type Vector = vectors.Vector
local type Point = points.Point

local dino_inputs = {}

local function handle_jump_input(
    dt: number, player: Player, blocks_jump: ReadableGroup<Kinematic>, lookup: Lookup
)
    local function jump_is_possible(jump_to: Point): boolean
        local jump_landing_area = hitboxes.new_block(jump_to)

        -- Collision is done with hitboxes but here we care about
        -- movementboxes, check in an area around and then manually
        -- check for movementbox overlap
        local blocks_jumps_close = lookup:in_box_and_group(
            jump_landing_area:expand(grid.TILE_SIZE), blocks_jump
        )

        for _, possible_jump_block in ipairs(blocks_jumps_close) do
            if jump_landing_area:overlap(possible_jump_block:movementbox()) then
                return false
            end
        end

        -- Finally check that jump area is contained in play area
        return grid.area():contains(jump_landing_area)
    end

    local function try_all_jumps_for(jump_direction: Vector): Point | nil
        -- Try to jump as far as possible first
        for nbr_of_blocks_to_jump = player:get_max_jump_dist(), 1, -1 do
            local jump_to = player.position:move(
                jump_direction:scale(grid.TILE_SIZE * nbr_of_blocks_to_jump)
            )
            local jump_candidates = {jump_to, grid.snap_to(jump_to)}

            for _, jump_candiated in ipairs(jump_candidates) do
                if jump_is_possible(jump_candiated) then
                    return jump_candiated
                end
            end
        end

        return nil
    end

    local function get_jump_directions(): {Vector}
        local result: {Vector} = {}

        if lutro.joystick.isDown(player.id, joysticks.BUTTONS.DOWN) then
            table.insert(result, vectors.new(0, 1))
        end
        if lutro.joystick.isDown(player.id, joysticks.BUTTONS.UP) then
            table.insert(result, vectors.new(0, -1))
        end
        if lutro.joystick.isDown(player.id, joysticks.BUTTONS.RIGHT) then
            table.insert(result, vectors.new(1, 0))
        end
        if lutro.joystick.isDown(player.id, joysticks.BUTTONS.LEFT) then
            table.insert(result, vectors.new(-1, 0))
        end

        return result
    end

    local function get_jump_target(): Point | nil
        for _, jump_direction in ipairs(get_jump_directions()) do
            local jump_to = try_all_jumps_for(jump_direction)
            if jump_to then
                return jump_to
            end
        end
    end

    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.B) and player:can_jump() then
        local dino = player.dino
        dino.jump_powerup_for = dino.jump_powerup_for + dt
    end

    if
        (joysticks.is_released(player.id, joysticks.BUTTONS.B) and player:can_jump())
        or player:must_jump()
    then
        local jump_to = get_jump_target()
        player:jump_with_dino(jump_to)
    end
end

--- A dash only starts toward an open tile; facing a block or bomb the button
-- does nothing instead of crashing on the spot. It asks the same closed
-- tiles the walk does, so a dash never starts only to be blocked at once.
local function is_open_ahead(
    player: Player, blocks_jump: ReadableGroup<Kinematic>, lookup: Lookup
): boolean
    local ahead = grid.tile_ahead_of(player.position, player.direction)
    local close_obstacles = lookup:in_box_and_group(
        hitboxes.new_block(ahead), blocks_jump
    )
    return closed_tiles.new(close_obstacles):is_open(grid.tile_indices(ahead))
end

local function handle_dash_input(
    player: Player, blocks_jump: ReadableGroup<Kinematic>, lookup: Lookup
)
    if
        joysticks.is_pressed(player.id, joysticks.BUTTONS.B)
        and is_open_ahead(player, blocks_jump, lookup)
    then
        player:dash_with_dino()
    end
end

local SHORTEST_THROW = 2
local THROW_CHARGE_TIME_PER_TILE = 4 / 60

local function handle_throw_input(
    dt: number,
    player: Player,
    bombs_: Bombs,
    bombs_group: ReadableGroup<Bomb>,
    lookup: Lookup
)
    local dino = player.dino
    local longest_throw = dino.level * 2

    local function get_bomb_to_throw(): Bomb | nil
        local throw_bomb_from = grid.tile_ahead_of(player.position, player.direction)
        local area_bomb_can_be_in = hitboxes.new_block(throw_bomb_from)
        local bombs_to_throw = lookup:in_box_and_group(area_bomb_can_be_in, bombs_group)
        for _, bomb_to_throw in ipairs(bombs_to_throw) do
            if not bomb_to_throw.sliding then
                return bomb_to_throw
            end
        end

        return nil
    end

    local function charged_tiles(): integer
        local charged = math.floor(dino.throw_powerup_for / THROW_CHARGE_TIME_PER_TILE)
        return math.min(SHORTEST_THROW + charged, longest_throw)
    end

    local function must_throw(): boolean
        local is_charging = dino.throw_powerup_for > 0
        return is_charging and charged_tiles() == longest_throw
    end

    if joysticks.is_released(player.id, joysticks.BUTTONS.B) or must_throw() then
        local bomb_to_throw = get_bomb_to_throw()
        if not (bomb_to_throw is nil) then
            local throw = vectors.from_direction(player.direction):scale(
                charged_tiles() * grid.TILE_SIZE
            )
            bombs_:throw_existing(bomb_to_throw, bomb_to_throw.position:move(throw))
            player:recover_from_throw()
        end
        dino.throw_powerup_for = 0
    elseif lutro.joystick.isDown(player.id, joysticks.BUTTONS.B) then
        local bomb_to_throw = get_bomb_to_throw()
        if not (bomb_to_throw is nil) then
            dino.throw_powerup_for = dino.throw_powerup_for + dt
        end
    else
        dino.throw_powerup_for = 0
    end
end

local function handle_stun_cry_input(player: Player)
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.B) then
        player:stun_cry_with_dino()
    end
end

local function handle_sonic_blast_input(player: Player)
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.B) then
        player:sonic_blast_with_dino()
    end
end

function dino_inputs.handle(
    dt: number,
    player: Player,
    bombs_: Bombs,
    blocks_jump: ReadableGroup<Kinematic>,
    bombs_group: ReadableGroup<Bomb>,
    lookup: Lookup
)
    if player.dino then
        if player.dino.color == "pink" then
            handle_jump_input(dt, player, blocks_jump, lookup)
        elseif player.dino.color == "green" then
            handle_dash_input(player, blocks_jump, lookup)
        elseif player.dino.color == "blue" then
            handle_throw_input(dt, player, bombs_, bombs_group, lookup)
        elseif player.dino.color == "yellow" then
            handle_stun_cry_input(player)
        elseif player.dino.color == "purple" then
            handle_sonic_blast_input(player)
        end
    end
end

return dino_inputs
