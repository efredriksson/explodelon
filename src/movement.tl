local bombs = require("bombs.bombs")
local lightning_bombs = require("bombs.lightning_bombs")
local closed_tiles = require("closed_tiles")
local dino_dash = require("dino_dash")
local collision = require("engine.collision")
local vectors = require("engine.geometry.vectors")
local joysticks = require("engine.joysticks")
local grid_walk = require("grid_walk")
local ice = require("ice")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local players = require("players")
local settings = require("settings")

local type Bomb = bombs.Bomb
local type Kinematic = require("kinematic")
local type LightningBombs = lightning_bombs.LightningBombs
local type Player = players.Player
local type ReadableGroup = collision.ReadableGroup
local type Lookup = collision.Lookup
local type Direction = vectors.Direction
local type Gait = grid_walk.Gait
local type GridWalk = grid_walk.GridWalk
local type IsOpen = grid_walk.IsOpen

local function get_moves_from_input(player: Player): {Direction}
    local held: {Direction} = {}

    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.DOWN) then
        table.insert(held, "down")
    end
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.UP) then
        table.insert(held, "up")
    end
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.RIGHT) then
        table.insert(held, "right")
    end
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.LEFT) then
        table.insert(held, "left")
    end

    return held
end

local movement = {}

local function kick_bomb_ahead(
    player: Player,
    direction: Direction,
    close_bombs: {Bomb},
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
)
    local ahead = grid.tile_ahead_of(player.position, direction)
    local function lies_ahead(bomb: Bomb): boolean
        return grid.snap_to(bomb.position):equal(ahead)
    end
    for _, bomb in ipairs(itertools.filter(close_bombs, lies_ahead)) do
        local can_move = bomb:can_move(
            vectors.from_direction(direction):scale(grid.TILE_SIZE),
            blocks_bombs,
            players_,
            bombs_,
            lookup
        )
        if can_move.yes then
            bomb:kick(can_move.in_direction)
        end
    end
end

--- The "slide" action is a dash's brake, and it keeps to the dash's line.
local function is_dashing(player: Player): boolean
    return player.action == "dash" or player.action == "slide"
end

local function gait_of(player: Player): Gait
    if is_dashing(player) then
        return "dash"
    end
    return "walk"
end

local function walking_directions(player: Player, held: {Direction}): {Direction}
    if is_dashing(player) then
        return dino_dash.directions(
            player.direction, player.dino.level, held, player.action == "slide"
        )
    end
    return held
end

--- Which tiles a step may enter, and the bombs close enough to be kicked.
local function surroundings(
    player: Player,
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
): IsOpen, {Bomb}
    -- Looking for an opening ahead reaches the neighbours of the next tile.
    local area = player:movementbox():expand(grid.TILE_SIZE * 3)
    local close_bombs = lookup:in_box_and_group(area, bombs_)
    local close_lightning_bombs = lookup:in_box_and_group(
        area, lightning_bombs_.on_ground
    )
    local closed = closed_tiles.new(
        itertools.combine(
            lookup:in_box_and_group(area, blocks_bombs),
            close_lightning_bombs,
            close_bombs
        )
    )
    local function is_open(i: integer, j: integer): boolean
        return closed:is_open(i, j)
    end
    return is_open, close_bombs
end

local function finish_move(
    player: Player,
    walk: GridWalk,
    facing: Direction,
    held: {Direction},
    close_bombs: {Bomb},
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
)
    player.last_step_axis = walk.last_axis
    player:set_movement(grid.position_from_area(walk.position), facing)
    if walk.blocked and player.has_kick then
        kick_bomb_ahead(
            player, walk.facing, close_bombs, blocks_bombs, players_, bombs_, lookup
        )
    end
    if is_dashing(player) then
        if walk.blocked then
            player:end_dash()
        end
    else
        player:set_action(#held ~= 0 and "walk" or "idle")
    end
end

local function walk_on_grid(
    player: Player,
    dt: number,
    speed: number,
    held: {Direction},
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
)
    local is_open, close_bombs = surroundings(
        player, lightning_bombs_, blocks_bombs, bombs_, lookup
    )
    local pixels, carry = grid_walk.pixels_this_frame(speed, dt, player.walk_carry)
    local walk = grid_walk.walk(
        grid.position_in_area(player.position:rounded()),
        walking_directions(player, held),
        player.last_step_axis,
        player.direction,
        pixels,
        is_open,
        gait_of(player)
    )
    player.walk_carry = carry
    finish_move(
        player,
        walk,
        walk.facing,
        held,
        close_bombs,
        blocks_bombs,
        players_,
        bombs_,
        lookup
    )
end

--- Facing follows what the player taps rather than the way they glide, so dino
-- abilities such as roar and bomb throw can aim mid-glide.
local function facing_on_ice(facing: Direction, held: {Direction}): Direction
    if itertools.contains(held, facing) then
        return facing
    end
    return held[1] or facing
end

local function glide_on_ice(
    player: Player,
    dt: number,
    held: {Direction},
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
)
    local is_open, close_bombs = surroundings(
        player, lightning_bombs_, blocks_bombs, bombs_, lookup
    )
    local glide = ice.glide(
        grid.position_in_area(player.position:rounded()),
        ice.velocity(
            player.ice_velocity, held, player:get_speed(), dt, settings.game_rules.ice
        ),
        player.ice_carry,
        dt,
        player.last_step_axis,
        player.direction,
        held,
        is_open
    )
    player.ice_velocity = glide.velocity
    player.ice_carry = glide.carry
    finish_move(
        player,
        glide.walk,
        facing_on_ice(player.direction, held),
        held,
        close_bombs,
        blocks_bombs,
        players_,
        bombs_,
        lookup
    )
end

--- On ice a dash builds up to its speed instead of starting at it. It keeps its
-- speed through a steered turn, but a glide against the dash gives it none.
local function speed_up_dash_on_ice(player: Player, dt: number): number
    local dash_line = vectors.from_direction(player.direction)
    local function speed_kept(): number
        if player.ice_velocity:dot_product(dash_line) < 0 then
            return 0
        end
        return player.ice_velocity:length()
    end
    local speed = ice.speed_toward(
        speed_kept(), player:get_speed(), dt, settings.game_rules.ice
    )
    player.ice_velocity = dash_line:scale(speed)
    return speed
end

local function start_brake_on_reverse(player: Player, held: {Direction})
    if player:can_slide() and dino_dash.is_reversing(player.direction, held) then
        player:slide_with_dino()
    end
end

local function apply_moves(
    player: Player,
    dt: number,
    held: {Direction},
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup,
    ice_sliding: boolean
)
    start_brake_on_reverse(player, held)
    if ice_sliding and not is_dashing(player) then
        glide_on_ice(
            player, dt, held, lightning_bombs_, blocks_bombs, players_, bombs_, lookup
        )
        return
    end
    local function walking_speed(): number
        if ice_sliding then
            return speed_up_dash_on_ice(player, dt)
        end
        return player:get_speed_over(dt)
    end
    walk_on_grid(
        player,
        dt,
        walking_speed(),
        held,
        lightning_bombs_,
        blocks_bombs,
        players_,
        bombs_,
        lookup
    )
end

function movement.set_position_and_dir_from_input(
    player: Player,
    dt: number,
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup,
    ice_sliding: boolean
)
    apply_moves(
        player,
        dt,
        get_moves_from_input(player),
        lightning_bombs_,
        blocks_bombs,
        players_,
        bombs_,
        lookup,
        ice_sliding
    )
end

--- Like set_position_and_dir_from_input, but fed a scripted held-direction list
-- so menu-preview drones reuse the real movement, kick and belt pipeline.
function movement.set_position_and_dir_scripted(
    player: Player,
    dt: number,
    held: {Direction},
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup,
    ice_sliding: boolean
)
    apply_moves(
        player,
        dt,
        held,
        lightning_bombs_,
        blocks_bombs,
        players_,
        bombs_,
        lookup,
        ice_sliding
    )
end

return movement
