local bombs = require("bombs.bombs")
local lightning_bombs = require("bombs.lightning_bombs")
local collision = require("engine.collision")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local joysticks = require("engine.joysticks")
local itertools = require("itertools")
local grid = require("level_layout.grid")
local players = require("players")
local settings = require("settings")

local type Action = players.Action
local type Bomb = bombs.Bomb
local type Kinematic = require("kinematic")
local type LightningBomb = lightning_bombs.LightningBomb
local type LightningBombs = lightning_bombs.LightningBombs
local type Player = players.Player
local type ReadableGroup = collision.ReadableGroup
local type Lookup = collision.Lookup
local type Direction = vectors.Direction
local type Vector = vectors.Vector
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local record Movement
    dxdy: Vector
    dir: Direction
end

function Movement.new(dxdy: Vector, dir: Direction): Movement
    local self: Movement = setmetatable({}, {__index = Movement})
    self.dir = dir
    self.dxdy = dxdy
    return self
end

function Movement.new_from_player(dt: number, player: Player): Movement
    local self: Movement = setmetatable({}, {__index = Movement})
    self.dir = player.direction
    self.dxdy = vectors.from_direction(self.dir):scale(dt * player:get_speed())
    return self
end

local record CheckedMovement
    position: Point
    spent: boolean
    cuts_corner: boolean
    constrained: boolean -- true if anything was touched: block, bomb, boundary, or corner cut
    bombs_kicked: {{Bomb, Vector}}
end

function CheckedMovement.new(
    position: Point,
    spent: boolean,
    cuts_corner: boolean,
    bombs_kicked?: {{Bomb, Vector}}
): CheckedMovement
    local self: CheckedMovement = setmetatable({}, {__index = CheckedMovement})
    self.position = position
    self.spent = spent
    self.cuts_corner = cuts_corner
    self.constrained = not spent or cuts_corner
    self.bombs_kicked = bombs_kicked or {}
    return self
end

local record MovementWithCheck
    dxdy: Vector
    dir: Direction
    check: CheckedMovement
end

function MovementWithCheck.new(
    dxdy: Vector, dir: Direction, check: CheckedMovement
): MovementWithCheck
    local self: MovementWithCheck = setmetatable({}, {__index = MovementWithCheck})
    self.dir = dir
    self.dxdy = dxdy
    self.check = check
    return self
end

local function get_moves_from_input(player: Player, dt: number): {Movement}
    local result: {Movement} = {}

    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.DOWN) then
        table.insert(
            result, Movement.new(vectors.new(0, dt * player:get_speed()), "down")
        )
    end
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.UP) then
        table.insert(
            result, Movement.new(vectors.new(0, -dt * player:get_speed()), "up")
        )
    end
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.RIGHT) then
        table.insert(
            result, Movement.new(vectors.new(dt * player:get_speed(), 0), "right")
        )
    end
    if lutro.joystick.isDown(player.id, joysticks.BUTTONS.LEFT) then
        table.insert(
            result, Movement.new(vectors.new(-dt * player:get_speed(), 0), "left")
        )
    end

    return result
end

--- Sign of a number represented as 1 or -1
local function sign_of(number: number): integer
    return number > 0 and 1 or (number == 0 and 0 or -1)
end

--- Split movement that goes against block into parts for walking corner.
-- If at just the corner the movement length will be split so the returned
-- vector represents moving up to the corner and then down the corner with
-- what is left. Signs of movement are handled but it is always assumed that
-- we are walking against the wall on the y-axis. If this is not the case
-- the vector returned have to be permutated.
local function around_corner_move(
    movement_len: number, dist_to_corner: number, pos_and_block_lateral_diff: number
): Vector
    local movement_dist = math.abs(movement_len)
    local movement_towards_corner = math.min(dist_to_corner, movement_dist)
    local movement_down_corner = movement_dist - movement_towards_corner

    return vectors.new(
        sign_of(pos_and_block_lateral_diff) * movement_towards_corner,
        sign_of(movement_len) * movement_down_corner
    )
end

local function in_corridor_and_walking_against_wall(
    position: Point, walk_dir: Direction
): boolean
    local local_pos = grid.get_local_tile_position(position)
    local in_vertical_corridor = local_pos.x == 0 and local_pos.y > 0
    local in_horizontal_corridor = local_pos.y == 0 and local_pos.x > 0

    return (in_vertical_corridor and (walk_dir == "left" or walk_dir == "right"))
        or (in_horizontal_corridor and (walk_dir == "up" or walk_dir == "down"))
end

local function in_end_of_corridor_and_walking_out(
    movement: MovementWithCheck, player_pos: Point
): boolean
    local local_pos = grid.get_local_tile_position(player_pos)

    local function first_half_of_block(val: number): boolean
        return val < grid.TILE_SIZE / 2 and val > 0
    end
    local function second_half_of_block(val: number): boolean
        return val > grid.TILE_SIZE / 2
    end

    return (movement.dir == "down" and second_half_of_block(local_pos.y))
        or (movement.dir == "up" and first_half_of_block(local_pos.y))
        or (movement.dir == "right" and second_half_of_block(local_pos.x))
        or (movement.dir == "left" and first_half_of_block(local_pos.x))
end

local function restrict_player_movement(
    player: Player,
    movement: Vector,
    blocks: {Kinematic},
    close_lightning_bombs: {LightningBomb},
    blocks_bombs: ReadableGroup<Kinematic>,
    close_bombs: {Bomb},
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
): CheckedMovement
    local margin_for_corner_assist = 8
    local new_position = player.position:move(movement)
    local new_hitbox = player:movementbox():shift(movement)

    local function move_against_block(
        movement_len: number,
        pos_and_block_lateral_diff: number,
        walk_along_y_axis: boolean
    ): CheckedMovement
        local dist_to_corner = grid.TILE_SIZE - math.abs(pos_and_block_lateral_diff)

        if dist_to_corner > margin_for_corner_assist then
            return CheckedMovement.new(player.position, false, false)
        end

        local along_wall = around_corner_move(
            movement_len, dist_to_corner, pos_and_block_lateral_diff
        ):permutate_if(walk_along_y_axis)

        -- Using 'new_position' instead of 'player_pos' here is not a bug, this
        -- actually makes corner movement smoother and feel much better.
        -- It also makes so you move over the corner, i.e 'cutting the corner'
        return CheckedMovement.new(new_position:move(along_wall), true, true)
    end

    local old_hitbox = player:movementbox()
    local function walking_further_into_block(block: Rectangle): boolean
        if not new_hitbox:overlap(block) then
            return false
        end

        local new_dist_to_1_ton_block = block:center_distance(new_hitbox)
        local old_dist_to_1_ton_block = block:center_distance(old_hitbox)
        return new_dist_to_1_ton_block < old_dist_to_1_ton_block
    end

    local function check_block_collision(block_box: Rectangle): CheckedMovement
        if movement.x == 0 then
            return move_against_block(
                movement.y, player.position.x - block_box.x, false
            )
        elseif movement.y == 0 then
            return move_against_block(movement.x, player.position.y - block_box.y, true)
        else
            assert(false, "Bad movement vector")
        end
    end

    local bombs_player_is_inside: {Kinematic: Kinematic} = {}
    for _, bomb in ipairs(close_bombs) do
        if bomb.position:distance_to(player.position) <= grid.TILE_SIZE * (3 / 4)
            and not bomb.has_been_kicked then
            bombs_player_is_inside[bomb] = bomb
        end
    end
    for _, bomb in ipairs(close_lightning_bombs) do
        if bomb.position:distance_to(player.position) <= grid.TILE_SIZE * (3 / 4) then
            bombs_player_is_inside[bomb] = bomb
        end
    end

    -- Attempt a corner cut around the given hitbox. Returns the cut movement if
    -- the path is clear of all blocks, bombs and lightning bombs, nil otherwise.
    -- skip excludes the obstacle being cut around. bombs_player_is_inside are
    -- also excluded since the player can freely overlap them during the cut.
    local function try_corner_cut(
        hitbox: Rectangle, skip?: Kinematic
    ): CheckedMovement | nil
        local result = check_block_collision(hitbox)
        if not result.cuts_corner then
            return nil
        end
        local corner_cut_hitbox = player:movementbox():shift(
            player.position:vector_to(result.position)
        )
        local all_obstacles = itertools.combine(
            blocks, close_bombs, close_lightning_bombs
        )
        local function not_skipped(obstacle: Kinematic): boolean
            return obstacle ~= skip and not bombs_player_is_inside[obstacle]
        end
        for _, obstacle in ipairs(itertools.filter(all_obstacles, not_skipped)) do
            if corner_cut_hitbox:overlap(obstacle:movementbox()) then
                return nil
            end
        end
        return result
    end

    for _, bomb in ipairs(close_bombs) do
        local bomb_hitbox = bomb:movementbox()
        if walking_further_into_block(bomb_hitbox)
            and not bombs_player_is_inside[bomb] then
            -- If a bomb has been kicked then it is no longer to move
            -- freely in far inside it. This is to stop moving through
            -- bombs that are kicked against a player.
            local corner_cut = try_corner_cut(bomb_hitbox, bomb)
            if corner_cut then
                return corner_cut
            end
            local kicked_bombs: {{Bomb, Vector}} = {}
            if player.has_kick then
                local kick_direction = movement:normalize()
                local can_move = bomb:can_move(
                    kick_direction:scale(grid.TILE_SIZE),
                    blocks_bombs,
                    players_,
                    bombs_,
                    lookup
                )
                if can_move.yes then
                    -- Walking into bomb and at edge of bomb then kick
                    table.insert(kicked_bombs, {bomb, can_move.in_direction})
                end
            end
            -- Not allowed to walk further into bomb if at edge
            return CheckedMovement.new(player.position, false, false, kicked_bombs)
        end
    end

    for _, bomb in ipairs(close_lightning_bombs) do
        local bomb_hitbox = bomb:movementbox()
        if walking_further_into_block(bomb_hitbox)
            and not bombs_player_is_inside[bomb] then
            local corner_cut = try_corner_cut(bomb_hitbox, bomb)
            if corner_cut then
                return corner_cut
            end
            -- Not allowed to walk further into bomb if at edge
            return CheckedMovement.new(player.position, false, false)
        end
    end

    for _, block in ipairs(blocks) do
        local block_box = block:movementbox()
        if walking_further_into_block(block_box) then
            local corner_cut = try_corner_cut(block_box, block)
            if corner_cut then
                return corner_cut
            end
            return CheckedMovement.new(player.position, false, false)
        end
    end

    if not grid.area():contains(new_hitbox) then
        local clamped_position = grid.area():clamp(new_hitbox):top_left()
        return CheckedMovement.new(clamped_position, false, false)
    end

    return CheckedMovement.new(new_position, true, false)
end

local function get_new_player_orientation(
    player_dir: Direction,
    directions: {Movement},
    blocks: {Kinematic},
    lightning_bombs_on_ground: ReadableGroup<LightningBomb>,
    player: Player,
    max_directions: integer,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup
): Direction, Point, boolean
    --- Get movement priority, lower number is higher priority.
    -- For example walking out of corridor and cutting corner
    -- have a low priority and should be tried last. This is
    -- mainly to sort and handle all cases when the user press multiple
    -- directions in a deterministic and expected way.
    local function movement_prio(movement: MovementWithCheck): integer
        if in_end_of_corridor_and_walking_out(movement, player.position) then
            -- On ice, pressing down while sliding horizontally can put the player
            -- slightly past the tile midpoint, which triggers
            -- in_end_of_corridor_and_walking_out for the downward corner cut.
            -- Without this split, the corner cut ties with the horizontal
            -- movement at prio 4, the horizontal fires first, and the corner
            -- cut is dropped by the constrained early-break.
            if movement.check.cuts_corner then
                return 4
            end
            return 5
        elseif movement.check.cuts_corner then
            return 3
        elseif in_corridor_and_walking_against_wall(player.position, movement.dir) then
            return 2
        else
            return 1
        end
    end

    local function sort_directions_by_prio(to_sort: {MovementWithCheck})
        local function compare(m1: MovementWithCheck, m2: MovementWithCheck): boolean
            return movement_prio(m1) < movement_prio(m2)
        end
        table.sort(to_sort, compare)
    end

    local cur_position = player.position
    local cur_direction = player_dir
    local directions_checks: {MovementWithCheck} = {}
    local close_bombs = lookup:in_box_and_group(
        player:movementbox():expand(grid.TILE_SIZE), bombs_
    )
    local close_lightning_bombs = lookup:in_box_and_group(
        player:movementbox():expand(grid.TILE_SIZE), lightning_bombs_on_ground
    )
    for _, direction in ipairs(directions) do
        local check = restrict_player_movement(
            player,
            direction.dxdy,
            blocks,
            close_lightning_bombs,
            blocks_bombs,
            close_bombs,
            players_,
            bombs_,
            lookup
        )
        table.insert(
            directions_checks,
            MovementWithCheck.new(direction.dxdy, direction.dir, check)
        )
    end

    sort_directions_by_prio(directions_checks)

    local function any_constrained(checks: {MovementWithCheck}): boolean
        for _, dc in ipairs(checks) do
            if dc.check.constrained then
                return true
            end
        end
        return false
    end

    local constrained = any_constrained(directions_checks)

    local directions_applied = 0
    for _, direction in ipairs(directions_checks) do
        local check = direction.check
        -- Accumulate displacement so movements compose rather than overwrite
        cur_position = cur_position:move(player.position:vector_to(check.position))
        cur_direction = direction.dir
        for _, bomb_kicked in ipairs(check.bombs_kicked) do
            local bomb = bomb_kicked[1]
            local kick_direction = bomb_kicked[2]
            bomb:kick(kick_direction)
        end
        if check.spent then
            directions_applied = directions_applied + 1

            if constrained or directions_applied >= max_directions then
                break
            end
        end
    end
    return cur_direction, cur_position, constrained
end

local movement = {}
local INVERTED_DIRECTIONS: {Direction: Direction} = {
    up = "down", down = "up", left = "right", right = "left"
}

local function inputs_for_sliding(player: Player, move_inputs: {Movement}): boolean
    for _, move in ipairs(move_inputs) do
        if move.dir == INVERTED_DIRECTIONS[player.direction] then
            return true
        end
    end

    return false
end

local function get_moves(
    player: Player, move_inputs: {Movement}, momentum: Movement
): {Movement}
    if player.action == "slide" then
        return {momentum}
    elseif player.action == "dash" then
        if player.dino and player.dino.level >= 3 then
            -- For level 3 dinos then check if direction is changed which is
            -- allowed for highest level dino
            for _, move in ipairs(move_inputs) do
                if move.dir ~= player.direction then
                    -- Also return move to continue with dash which will be used
                    -- if changing direction does not work
                    return {move, momentum}
                end
            end
        end

        return {momentum}
    else
        return move_inputs
    end
end

local function is_diagonal(moves: {Movement}): boolean
    local has_x = false
    local has_y = false
    for _, move in ipairs(moves) do
        if move.dxdy.x ~= 0 then
            has_x = true
        end
        if move.dxdy.y ~= 0 then
            has_y = true
        end
    end
    return has_x and has_y
end

local function any_move_has_direction(moves: {Movement}, dir: Direction): boolean
    for _, move in ipairs(moves) do
        if move.dir == dir then
            return true
        end
    end
    return false
end

local function direction_for_diagonal(
    moves: {Movement},
    current_dir: Direction,
    computed_dir: Direction,
    constrained: boolean
): Direction
    if constrained then
        return computed_dir
    end

    if is_diagonal(moves) and any_move_has_direction(moves, current_dir) then
        return current_dir
    end
    return computed_dir
end

local function direction_from_dominant_velocity(
    vel: Vector, current_dir: Direction
): Direction
    if math.abs(vel.x) > math.abs(vel.y) then
        return vel.x > 0 and "right" or "left"
    elseif math.abs(vel.y) > math.abs(vel.x) then
        return vel.y > 0 and "down" or "up"
    elseif vel.x ~= 0 then
        return vel.x > 0 and "right" or "left"
    elseif vel.y ~= 0 then
        return vel.y > 0 and "down" or "up"
    else
        return current_dir
    end
end

local function get_ice_moves(
    player: Player, dt: number, move_inputs: {Movement}
): {Movement}
    local max_speed = player:get_speed()
    local ice = settings.game_rules.ice
    local acceleration = max_speed * ice.acceleration_factor
    local friction = max_speed * ice.friction_factor

    local function update_axis(v: number, pos: boolean, neg: boolean): number
        if pos then
            return math.min(max_speed, v + acceleration * dt)
        elseif neg then
            return math.max(-max_speed, v - acceleration * dt)
        elseif math.abs(v) <= friction * dt then
            return 0
        elseif v > 0 then
            return v - friction * dt
        else
            return v + friction * dt
        end
    end

    local new_vel = vectors.new(
        update_axis(
            player.ice_velocity.x,
            any_move_has_direction(move_inputs, "right"),
            any_move_has_direction(move_inputs, "left")
        ),
        update_axis(
            player.ice_velocity.y,
            any_move_has_direction(move_inputs, "down"),
            any_move_has_direction(move_inputs, "up")
        )
    )
    player.ice_velocity = new_vel

    local result: {Movement} = {}
    if new_vel.x ~= 0 then
        local dir: Direction = new_vel.x > 0 and "right" or "left"
        table.insert(result, Movement.new(vectors.new(new_vel.x * dt, 0), dir))
    end
    if new_vel.y ~= 0 then
        local dir: Direction = new_vel.y > 0 and "down" or "up"
        table.insert(result, Movement.new(vectors.new(0, new_vel.y * dt), dir))
    end
    return result
end

function movement.set_position_and_dir_from_input(
    player: Player,
    dt: number,
    blocks: {Kinematic},
    lightning_bombs_: LightningBombs,
    blocks_bombs: ReadableGroup<Kinematic>,
    players_: ReadableGroup<Player>,
    bombs_: ReadableGroup<Bomb>,
    lookup: Lookup,
    ice_sliding: boolean
)
    local move_inputs = get_moves_from_input(player, dt)
    local momentum = Movement.new_from_player(dt, player)
    local moves = get_moves(player, move_inputs, momentum)
    local player_action: Action = #moves ~= 0 and "walk" or "idle"

    if ice_sliding then
        moves = get_ice_moves(player, dt, moves)
    end

    if player:can_slide() and inputs_for_sliding(player, move_inputs) then
        player:slide_with_dino()
    end

    local max_directions = (player.action == "slide" or player.action == "dash") and 1
        or 2
    local new_dir, new_pos, constrained = get_new_player_orientation(
        player.direction,
        moves,
        blocks,
        lightning_bombs_.on_ground,
        player,
        max_directions,
        blocks_bombs,
        players_,
        bombs_,
        lookup
    )
    local dominant_dir = direction_from_dominant_velocity(player.ice_velocity, new_dir)
    local updated_dir = direction_for_diagonal(
        moves, player.direction, dominant_dir, constrained
    )

    player:set_movement(new_pos, updated_dir)
    player:set_action(player_action)
end

return movement
