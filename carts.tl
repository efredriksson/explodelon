require("geometry")
require("level_map")
require("character_sprites")

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
    right = PLAYER_AREA:top_left():move(Vector.new(PLAYER_AREA.width, 0)),
    down = PLAYER_AREA:top_left():move(Vector.new(PLAYER_AREA.width, PLAYER_AREA.height)),
    left = PLAYER_AREA:top_left():move(Vector.new(0, PLAYER_AREA.height)),
}
local MOVE_DIRECTION_OF_SIDE: {Direction: Vector} = {
    up = Vector.new(1, 0),
    right = Vector.new(0, 1),
    down = Vector.new(-1, 0),
    left = Vector.new(0, -1),
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

local SIDES: {Direction} = {"up", "down", "left", "right"}
local CART_STATES: {CartState} = {"forward", "backward", "idle"}
local cart_images: {Direction: {CartState: Image}} = {}
local cart_heads: {CharacterSprite: {Direction: Image}} = {}

global function load_cart_assets()
    for _, side in ipairs(SIDES) do
        cart_images[side] = {}
        for _, state in ipairs(CART_STATES) do
            local asset_file = "assets/carts/" .. side .. "_" .. state .. ".png"
            cart_images[side][state] = lutro.graphics.newImage(asset_file)
        end
    end
    for _, sprite in ipairs(get_sprites()) do
        cart_heads[sprite] = {}
        for _, dir in ipairs(SIDES) do
            local asset_file = "assets/" .. sprite .. "/head_" .. dir .. ".png"
            cart_heads[sprite][dir] = lutro.graphics.newImage(asset_file)
        end
    end
end

local function cart_animation(side: Direction, state: CartState): Animation
	local image = cart_images[side][state]
	local nbr_steps = 2
	return Animation.new(image, image:getWidth() / nbr_steps, image:getHeight(), 1, 20)
end

local function get_cart_animations(): {Direction: {CartState: Animation}}
    local animations: {Direction: {CartState: Animation}} = {}
    for _, side in ipairs(SIDES) do
        animations[side] = {}
        for _, state in ipairs(CART_STATES) do
            animations[side][state] = cart_animation(side, state)
        end
    end

    return animations
end

global record PlayerCart
    id: integer
    position: number -- 1D position on cart rail 
    state: CartState
    previous_direction: CartState
    head: CharacterSprite
    turbo: boolean
    animations: {Direction: {CartState: Animation}}
end

function PlayerCart.new(id: integer, position: number, head: CharacterSprite): PlayerCart
    local self: PlayerCart = setmetatable({}, { __index = PlayerCart })
    self.id = id
    self.position = position
    self.head = head
    self.state = "idle"
    self.previous_direction = "idle"
    self.turbo = false
    self.animations = get_cart_animations()
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
    return self.animations[self:get_side()][self.state]
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
    self:_get_animation():update(dt)
end

function PlayerCart:_get_x_y_position(): Point
    local side = self:get_side()
    local side_move_len = self.position - DISTANCE_TO_SIDE[side]
    local side_start = START_POSITION_OF_SIDE[side]
    local move_dir = MOVE_DIRECTION_OF_SIDE[side]
    return side_start:move(move_dir:scale(side_move_len))
end

function PlayerCart:_get_draw_offset(): Vector
    local side = self:get_side()
    local animation = self:_get_animation()
    local height = animation.height
    local width = animation.width
    if side == "up" then
        return Vector.new(-width / 2, -(height + 1))
    elseif side == "right" then
        return Vector.new(1, -height / 2)
    elseif side == "down" then
        return Vector.new(-width / 2, -4)
    elseif side == "left" then
        return Vector.new(-(width + 1), -height / 2)
    end
end

function PlayerCart:_get_x_y_draw_position(): Point
    return self:_get_x_y_position():move(self:_get_draw_offset())
end

function PlayerCart:draw()
    local cart_pos = self:_get_x_y_draw_position()
    local animation = self:_get_animation()
    animation:draw(cart_pos.x, cart_pos.y)
    
    local head_image = cart_heads[self.head][HEAD_DIR_BY_SIDE[self:get_side()]]
    local head_pos = Point.new(
        cart_pos.x + animation.width / 2 - head_image:getWidth() / 2,
        cart_pos.y -(head_image:getHeight() - 4) / 2
    )
    lutro.graphics.draw(head_image, head_pos.x, head_pos.y)
end

function PlayerCart:set_state(state: CartState)
    self.state = state
    if state ~= "idle" then
        self.previous_direction = state
    end
end

global function handle_cart_move_input(cart: PlayerCart)
    cart:set_state("idle")

    local up = lutro.joystick.isDown(cart.id, JOYPAD_UP)
    local down = lutro.joystick.isDown(cart.id, JOYPAD_DOWN)
    local left = lutro.joystick.isDown(cart.id, JOYPAD_LEFT)
    local right = lutro.joystick.isDown(cart.id, JOYPAD_RIGHT)
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

    cart.turbo = lutro.joystick.isDown(cart.id, JOYPAD_A)
end
