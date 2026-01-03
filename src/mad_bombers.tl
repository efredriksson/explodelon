require("bombs")
local animations = require("animations")
local characters = require("characters")
local const = require("const")
local hitboxes = require("hitboxes")
local joysticks = require("joysticks")
local level_map = require("level_map")
local points = require("geometry.points")
local rectangles = require("geometry.rectangles")
local vectors = require("geometry.vectors")

local JOYPAD = joysticks.buttons()
local PLAYER_AREA = level_map.player_area()
local RAIL_LENGHT = PLAYER_AREA.width * 2 + PLAYER_AREA.height * 2
local CART_SPEEDS = {
    [false] = 60,
    [true] = 120,
}
local DISTANCE_TO_SIDE: {Direction: number} = {
    up = 0,
    right = PLAYER_AREA.width,
    down = PLAYER_AREA.width + PLAYER_AREA.height,
    left = PLAYER_AREA.width * 2 + PLAYER_AREA.height,
}
local START_POSITION_OF_SIDE: {Direction: Point} = {
    up = PLAYER_AREA:top_left(),
    right = PLAYER_AREA:top_left():move(
        vectors.new(PLAYER_AREA.width, 0)
    ),
    down = PLAYER_AREA:top_left():move(
        vectors.new(PLAYER_AREA.width, PLAYER_AREA.height)
    ),
    left = PLAYER_AREA:top_left():move(
        vectors.new(0, PLAYER_AREA.height)
    ),
}
local MOVE_DIRECTION_OF_SIDE: {Direction: Vector} = {
    up = vectors.new(1, 0),
    right = vectors.new(0, 1),
    down = vectors.new(-1, 0),
    left = vectors.new(0, -1),
}
local THROW_BOMB_DIRECTION_BY_SIDE: {Direction: Vector} = {
    up = vectors.new(0, 1),
    right = vectors.new(-1, 0),
    down = vectors.new(0, -1),
    left = vectors.new(1, 0),
}
local HEAD_DIR_BY_SIDE: {Direction: Direction} = {
    up = "down",
    down = "up",
    right = "left",
    left = "right",
}

global type CartState = enum
   "forward" -- Moving clockwise
   "backward" -- Moving anti-clockwise
   "idle"
end

global type CannonState = enum
   "ready"
   "pre-fire"
   "firing"
   "loading"
end

local type CartAnimations = {Direction: {CartState: Animation}}
local SIDES: {Direction} = {"up", "down", "left", "right"}
local CART_STATES: {CartState} = {"forward", "backward", "idle"}
local CANNON_RELOAD_TIME = 6.5
local CANNON_PRE_FIRE_TIME = 0.3
local cart_images: {Direction: {CartState: Image}} = {}
local cart_loading_images: {Direction: {CartState: Image}} = {}
local cart_firing_images: {Direction: Image} = {}
local cart_heads: {CharacterName: {Direction: Image}} = {}

local function cart_animation(image: Image): Animation
	local nbr_steps = 2
	return animations.new(image, image:getWidth() / nbr_steps, 0.05)
end

local function get_firing_animation(side: Direction): Animation
    local function animation_steps(): integer
        if side == "up" or side == "down" then
            return 4
        else
            return 5
        end
    end

    local image = cart_firing_images[side]
    return animations.new(image, image:getWidth() / animation_steps(), 0.1)
end

local function get_cart_animations(): CartAnimations, CartAnimations, CartAnimations
    local ready_animations: CartAnimations = {}
    local firing_animations: CartAnimations = {}
    local loading_animations: CartAnimations = {}
    for _, side in ipairs(SIDES) do
        ready_animations[side] = {}
        loading_animations[side] = {}
        firing_animations[side] = {}
        firing_animations[side]["idle"] = get_firing_animation(side)
        for _, state in ipairs(CART_STATES) do
            ready_animations[side][state] = cart_animation(cart_images[side][state])
            loading_animations[side][state] = cart_animation(
                cart_loading_images[side][state]
            )
        end
    end

    return ready_animations, loading_animations, firing_animations
end

global record PlayerCart is Entity
    id: integer
    position: number -- 1D position on cart rail 
    state: CartState
    previous_direction: CartState
    cannon: CannonState
    cannon_powerup_for: number
    head: CharacterName
    turbo: boolean
    reload_countdown: number
    animations: CartAnimations
    loading_animations: CartAnimations
    firing_animations: CartAnimations
end

function PlayerCart.new(
    id: integer, position: number, head: CharacterName
): PlayerCart
    local self: PlayerCart = setmetatable({}, { __index = PlayerCart })
    self.id = id
    self.position = position
    self.head = head
    self.state = "idle"
    self.previous_direction = "idle"
    self.cannon = "ready"
    self.cannon_powerup_for = 0.0
    self.turbo = false
    self.reload_countdown = 0.0
    self.animations, self.loading_animations, self.firing_animations = get_cart_animations()
    return self
end

function PlayerCart:get_side(): Direction
    if self.position < PLAYER_AREA.width then
        return "up"
    elseif self.position < PLAYER_AREA.width + PLAYER_AREA.height then
        return "right"
    elseif self.position < PLAYER_AREA.width * 2 + PLAYER_AREA.height then
        return "down"
    else
        return "left"
    end
end

function PlayerCart:_get_animation(): Animation
    local side = self:get_side()
    if self.cannon == "loading" then
        return self.loading_animations[side][self.state]
    elseif self.cannon == "firing" then
        assert(self.state == "idle")
        return self.firing_animations[side][self.state]
    else
        return self.animations[side][self.state]
    end
end

function PlayerCart:update(dt: number)
    local pos_dt = 0.0
    if self.state == "forward" then
        pos_dt = dt
    elseif self.state == "backward" then
        pos_dt = -dt
    end
    
    self.position = self.position + pos_dt * CART_SPEEDS[self.turbo]
    self.position = self.position % RAIL_LENGHT
    local animation = self:_get_animation()
    animation:update(dt)

    self.reload_countdown = self.reload_countdown - dt
    local time_to_fire = CANNON_RELOAD_TIME - CANNON_PRE_FIRE_TIME
    if self.cannon == "pre-fire" and self.reload_countdown < time_to_fire then
        self.cannon = "firing"
    elseif self.cannon == "firing" and animation.loops > 0 then
        self.cannon = "loading"
        animation:reset()
    elseif self.cannon ~= "ready" and self.reload_countdown <= 0 then
        self.cannon = "ready"
    end
end

function PlayerCart:get_x_y_position(): Point
    local side = self:get_side()
    local side_move_len = self.position - DISTANCE_TO_SIDE[side]
    local side_start = START_POSITION_OF_SIDE[side]
    local move_dir = MOVE_DIRECTION_OF_SIDE[side]
    return side_start:move(move_dir:scale(side_move_len))
end

-- This is the padding in the cart images
function PlayerCart:_get_cart_image_padding(): Vector
    local side = self:get_side()
    if side == "up" then
        return vectors.new(0, 5)
    elseif side == "right" then
        return vectors.new(-12, 0)
    elseif side == "down" then
        return vectors.new(0, -8)
    elseif side == "left" then
        return vectors.new(12, 0)
    end
end

function PlayerCart:_get_draw_offset(): Vector
    local side = self:get_side()
    local animation = self:_get_animation()
    local height = animation.height
    local width = animation.width
    local margin = 2 -- The cart is not directly at side line but at bit in
    if side == "up" then
        return vectors.new(-width / 2, -height - margin)
    elseif side == "right" then
        return vectors.new(2, -height / margin)
    elseif side == "down" then
        -- '-margin' as cart is rendered in player area
        return vectors.new(-width / 2, -margin)
    elseif side == "left" then
        return vectors.new(-width - margin, -height / 2)
    end
end

function PlayerCart:_get_x_y_draw_position(): Point
    return self:get_x_y_position():move(
        self:_get_draw_offset()
    ):move(self:_get_cart_image_padding())
end

function PlayerCart:get_position(): Point
    return self:get_x_y_position()
end

function PlayerCart:hitbox(): Rectangle
    local animation = self:_get_animation()
    local cart_pos = self:_get_x_y_draw_position()
    return rectangles.new(cart_pos.x, cart_pos.y, animation.width, animation.height)
end

function PlayerCart:draw()
    local cart_pos = self:_get_x_y_draw_position()
    local animation = self:_get_animation()
    animation:draw(cart_pos.x, cart_pos.y)

    if self.cannon ~= "ready" and self.reload_countdown % 0.05 < 0.025 then
        -- If not ready, head is blinking by only sometimes not rendering it below
        return
    end
    
    local side = self:get_side()
    local head_image = cart_heads[self.head][HEAD_DIR_BY_SIDE[side]]
    local cart_paddings = self:_get_cart_image_padding():abs()

    local function total_padding(): Vector
        if side == "down" or side == "up" then
            -- Up/Down carts have padding on both sides:
            return cart_paddings:scale(2)
        else
            return cart_paddings
        end
    end

    -- Final pixel tweaks for where head is on cart
    local function pixel_tweaks(): Vector
        if side == "up" then
            return vectors.new(0, 1)
        elseif side == "right" then
            return vectors.new(1, 3)
        elseif side == "left" then
            return vectors.new(0, 3)
        elseif side == "down" then
            return vectors.new(0, 0)
        end
    end

    local cart_half_size = vectors.new(
        animation.width, animation.height
    ):minus(total_padding()):scale(1/2)
    local head_pos = points.new(
        cart_pos.x + cart_half_size.x - head_image:getWidth() / 2,
        cart_pos.y + cart_paddings.y - head_image:getHeight() / 2
    ):move(pixel_tweaks())
    
    if side == "right" then
        -- Note, special case for the right hand side. This is because
        -- the right/left cart sprites are not centered with equal padding
        -- on both sides. 
        head_pos = head_pos:move(vectors.new(cart_paddings.x, 0))
    end
    lutro.graphics.draw(head_image, head_pos.x, head_pos.y)
end

function PlayerCart:set_state(state: CartState)
    self.state = state
    if state ~= "idle" then
        self.previous_direction = state
    end
end

function PlayerCart:fire_cannon(): Point, integer
    local fire_lenght = 2 + math.floor(self.cannon_powerup_for * 5)
    self.cannon_powerup_for = 0.0 -- Reset regardless if actually fire or not

    local side = self:get_side()
    local shoot_from = self:get_x_y_position()
    -- Adjust so we shoot from inside player area if 'down' or 'right'
    -- Also adjust for the cart position being its center for 'up' and 'down'
    if side == "down" then
        shoot_from = shoot_from:move(vectors.new(-const.BLOCK_SIZE / 2, -const.BLOCK_SIZE))
    elseif side == "up" then
        shoot_from = shoot_from:move(vectors.new(-const.BLOCK_SIZE / 2, 0))
    elseif side == "right" then
        shoot_from = shoot_from:move(vectors.new(-const.BLOCK_SIZE, 0))
    end
    shoot_from = level_map.snap_to_closest_grid_tile(shoot_from)

    local fired_bomb = hitboxes.new_block(shoot_from)
    if self.cannon ~= "ready" or not PLAYER_AREA:contains(fired_bomb) then
        return nil, nil
    end

    self:set_state("idle")
    self.cannon = "pre-fire"
    -- TODO: countdown is from when bomb as landed, can bounce for a while
    self.reload_countdown = CANNON_RELOAD_TIME
    return shoot_from, fire_lenght
end

function PlayerCart:firing_cannon(): boolean
    return self.cannon == "pre-fire" or self.cannon == "firing"
end

global record MadBombers
    by_player: {integer: PlayerCart}
    bombs: Bombs
end

local mad_bombers = {}

function mad_bombers.new(bombs: Bombs): MadBombers
    local self: MadBombers = setmetatable({}, { __index = MadBombers })
    self.by_player = {}
    self.bombs = bombs
    return self
end

function MadBombers:ensure_exist_for(player_id: integer, player_sprite: CharacterName)
    if not self.by_player[player_id] then
        self.by_player[player_id] = PlayerCart.new(player_id, 50, player_sprite)
    end
end

local function handle_cart_move_input(dt: number, bombs: Bombs, cart: PlayerCart)
    if cart:firing_cannon() then
        -- Not possible to do anything while firing
        return
    end

    cart:set_state("idle")

    local up = lutro.joystick.isDown(cart.id, JOYPAD.UP)
    local down = lutro.joystick.isDown(cart.id, JOYPAD.DOWN)
    local left = lutro.joystick.isDown(cart.id, JOYPAD.LEFT)
    local right = lutro.joystick.isDown(cart.id, JOYPAD.RIGHT)
    local right_or_left = right or left
    local up_or_down = up or down
    local side = cart:get_side()

    if (side == "up" or side == "down") and up_or_down then
        cart:set_state(cart.previous_direction)
    end
    if (side == "down" and right) or (side == "up" and left) then
        cart:set_state("backward")
    end
    if (side == "down" and left) or (side == "up" and right) then
        cart:set_state("forward")
    end
    if (side == "left" or side == "right") and right_or_left then
        cart:set_state(cart.previous_direction)
    end
    if (side == "left" and up) or (side == "right" and down) then
        cart:set_state("forward")
    end
    if (side == "left" and down) or (side == "right" and up) then
        cart:set_state("backward")
    end
    
    if lutro.joystick.isDown(cart.id, JOYPAD.R) and cart.cannon == "ready" then
        cart.cannon_powerup_for = cart.cannon_powerup_for + dt
    end

    if joysticks.is_released(cart.id, JOYPAD.R) or cart.cannon_powerup_for > 0.8 then
        local fire_from, fire_len = cart:fire_cannon()
        if fire_from then
            local fire_dir = THROW_BOMB_DIRECTION_BY_SIDE[side]
            local target = fire_from:move(fire_dir:scale(fire_len * const.BLOCK_SIZE))
            bombs:throw_bomb(fire_from, target)
        end
    end
    cart.turbo = lutro.joystick.isDown(cart.id, JOYPAD.A)
end

function MadBombers:update(dt: number)
    for _, cart in pairs(self.by_player) do
		handle_cart_move_input(dt, self.bombs, cart)
		cart:update(dt)
	end
end

local function sort_carts_by_y_cord(carts_to_sort: {PlayerCart})
	local function compare_cart_y_pos(c1: PlayerCart, c2: PlayerCart): boolean
		return c1:get_x_y_position().y < c2:get_x_y_position().y
	end
	table.sort(carts_to_sort, compare_cart_y_pos)
end

function MadBombers:to_draw(): {PlayerCart}
    local carts_to_draw: {PlayerCart} = {}

    for _, cart in pairs(self.by_player) do
		table.insert(carts_to_draw, cart)
	end

	sort_carts_by_y_cord(carts_to_draw)
    return carts_to_draw
end

function MadBombers.load_assets()
    local folder = "assets/carts/"

    for _, side in ipairs(SIDES) do
        cart_firing_images[side] = lutro.graphics.newImage(
            folder .. side .. "_shoot.png"
        )

        cart_images[side] = {}
        cart_loading_images[side] = {}
        for _, state in ipairs(CART_STATES) do
            local file_name = side .. "_" .. state .. ".png"
            cart_images[side][state] = lutro.graphics.newImage(folder .. file_name)
            cart_loading_images[side][state] = lutro.graphics.newImage(
                folder .. "loading_" .. file_name
            )
        end
    end
    for _, sprite in ipairs(characters.get_names()) do
        cart_heads[sprite] = {}
        for _, dir in ipairs(SIDES) do
            local asset_file = "assets/" .. sprite .. "/head_" .. dir .. ".png"
            cart_heads[sprite][dir] = lutro.graphics.newImage(asset_file)
        end
    end
end

return mad_bombers
