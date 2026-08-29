local audio = require("engine.audio")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local vectors = require("engine.geometry.vectors")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local fonts = require("fonts")
local screen = require("screen")

local type Color = images.Color
local type MenuFont = fonts.MenuFont
local type Point = points.Point
local type Rectangle = rectangles.Rectangle

local BACKDROP_TINT: Color = {0, 0, 0}
local BACKDROP_ALPHA = 130
local BACKDROP_PADDING = 6
local SCREEN_CENTER_X = screen.WIDTH / 2

local WHITE: Color = {255, 255, 255}
local AMBER: Color = {245, 197, 66}
local CYAN: Color = {89, 199, 232}
local PURPLE: Color = {186, 120, 224}
local RED: Color = {226, 71, 58}

local interface PlayerInfo
    has_cursor: function(self, player_id: integer): boolean
end

local record ControllerHints
    player_info: PlayerInfo
    hint_cooldown_time_left: number
    hint_backdrop: Rectangle
end

local controller_hints = {ControllerHints = ControllerHints, PlayerInfo = PlayerInfo}

-- Boxes match assets/controller_hint_pad.png
local PAD_POSITION = points.new(112, 164)
local PAD_OFFSET = vectors.new(PAD_POSITION.x, PAD_POSITION.y)

local R1_BOX = rectangles.new(59, 1, 17, 6):shift(PAD_OFFSET)
local DPAD_BOX = rectangles.new(7, 13, 15, 15):shift(PAD_OFFSET)
local Y_BOX = rectangles.new(65, 17, 7, 7):shift(PAD_OFFSET)
local B_BOX = rectangles.new(72, 23, 7, 7):shift(PAD_OFFSET)

local RIGHT_COLUMN_X = 216
local LEFT_LABEL_RIGHT_EDGE = 92
local LABEL_GAP = 8
local LEFT_SPINE_X = LEFT_LABEL_RIGHT_EDGE + LABEL_GAP

local SELECT_LABEL = "select"
local CHARACTER_LABEL = "character"
local WALK_LABEL = "walk in game"
local DROP_BOMB_LABEL = "drop bomb"
local DINO_ABILITY_LABEL = "dino ability"
local SPECIAL_BOMB_LABEL = "special bomb"

local DOT_SIZE = 5
local DOT_CENTER_OFFSET = math.floor(DOT_SIZE / 2)

local function row_center_y(box: Rectangle): number
    return math.floor(box:center().y)
end

local R1_ROW_Y = row_center_y(R1_BOX)
local B_ROW_Y = row_center_y(B_BOX)
local R1_BOX_RIGHT = R1_BOX.x + R1_BOX.width
local B_BOX_RIGHT = B_BOX.x + B_BOX.width

local Y_BOX_CENTER = Y_BOX:center()
local SPECIAL_BOMB_ROW_Y = Y_BOX.y + 35

local DPAD_ROW_Y = row_center_y(DPAD_BOX)
local ROW_HEIGHT = 8
local SELECT_ROW_Y = DPAD_ROW_Y - 15
local CHARACTER_ROW_Y = SELECT_ROW_Y + ROW_HEIGHT
local WALK_ROW_Y = CHARACTER_ROW_Y + 2 * ROW_HEIGHT

local SELECT_CHARACTER_BEND_Y = math.floor((SELECT_ROW_Y + CHARACTER_ROW_Y) / 2) + 3
local WALK_BEND_Y = WALK_ROW_Y + 3

local pad_image: Image
local amber_font: MenuFont
local cyan_font: MenuFont
local purple_font: MenuFont
local white_font: MenuFont
local red_font: MenuFont
local wrong_input_sound: Source
local special_bomb_corridor_x: number

local function hint_backdrop_bounds(): Rectangle
    local left_label_width = math.max(
        white_font:width(SELECT_LABEL),
        white_font:width(CHARACTER_LABEL),
        white_font:width(WALK_LABEL)
    )
    local right_label_width = math.max(
        amber_font:width(DROP_BOMB_LABEL), purple_font:width(DINO_ABILITY_LABEL)
    )

    local content_left = LEFT_LABEL_RIGHT_EDGE - left_label_width
    local content_right = RIGHT_COLUMN_X + LABEL_GAP + right_label_width
    local half_width = math.max(
        SCREEN_CENTER_X - content_left, content_right - SCREEN_CENTER_X
    )

    local top = PAD_POSITION.y
    local bottom = SPECIAL_BOMB_ROW_Y + 1

    return rectangles.new(
        SCREEN_CENTER_X - half_width, top, 2 * half_width, bottom - top
    ):expand(BACKDROP_PADDING)
end

function controller_hints.load_assets()
    pad_image = lutro.graphics.newImage("assets/controller_hint_pad.png")
    amber_font = fonts.new_menu_colored_outlined(AMBER)
    cyan_font = fonts.new_menu_colored_outlined(CYAN)
    purple_font = fonts.new_menu_colored_outlined(PURPLE)
    white_font = fonts.new_menu_white_outlined()
    red_font = fonts.new_menu_colored_outlined(RED)
    wrong_input_sound = audio.new_source("assets/wrong_input.wav", "static")
    special_bomb_corridor_x = PAD_POSITION.x + pad_image:getWidth() / 2
end

function controller_hints.new(player_info: PlayerInfo): ControllerHints
    local self: ControllerHints = setmetatable({}, {__index = ControllerHints})
    self.player_info = player_info
    self.hint_cooldown_time_left = 0
    self.hint_backdrop = hint_backdrop_bounds()
    return self
end

local function set_color(tint: Color, alpha?: number)
    lutro.graphics.setColor(tint[1], tint[2], tint[3], alpha or 255)
end

local function fill_rect(
    x: number, y: number, width: number, height: number, tint: Color, alpha?: number
)
    set_color(tint, alpha)
    lutro.graphics.rectangle("fill", x, y, width, height)
end

local function draw_hline(x0: number, x1: number, y: number, tint: Color)
    fill_rect(math.min(x0, x1), y, math.abs(x1 - x0) + 1, 1, tint)
end

local function draw_vline(x: number, y0: number, y1: number, tint: Color)
    fill_rect(x, math.min(y0, y1), 1, math.abs(y1 - y0) + 1, tint)
end

local function draw_dot(x: number, y: number, tint: Color)
    fill_rect(x, y, DOT_SIZE, DOT_SIZE, tint)
end

local function draw_dot_centered(x: number, y: number, tint: Color)
    draw_dot(x - DOT_CENTER_OFFSET, y - DOT_CENTER_OFFSET, tint)
end

local function draw_label(text: string, position: Point, font: MenuFont)
    set_color(WHITE)
    font:print(text, position)
end

local function draw_label_right_aligned(
    text: string, right_edge: number, y: number, font: MenuFont
)
    local x = right_edge - font:width(text)
    draw_label(text, points.new(x, y), font)
end

local function draw_column_leader(
    row_y: number, connector_right_x: number, tint: Color, label: string, font: MenuFont
)
    draw_hline(connector_right_x, RIGHT_COLUMN_X, row_y, tint)
    draw_dot(RIGHT_COLUMN_X, row_y - DOT_CENTER_OFFSET, tint)
    draw_label(label, points.new(RIGHT_COLUMN_X + LABEL_GAP, row_y - 3), font)
end

local function draw_right_column()
    draw_column_leader(R1_ROW_Y, R1_BOX_RIGHT, AMBER, DROP_BOMB_LABEL, amber_font)
    draw_column_leader(B_ROW_Y, B_BOX_RIGHT, PURPLE, DINO_ABILITY_LABEL, purple_font)
end

-- Avoids crossing r1 by routing left through the l1/r1 gap; label sits low,
-- clear of walking characters.
local function draw_special_bomb_line()
    draw_hline(special_bomb_corridor_x, Y_BOX_CENTER.x, Y_BOX_CENTER.y, CYAN)
    draw_vline(special_bomb_corridor_x, SPECIAL_BOMB_ROW_Y, Y_BOX_CENTER.y, CYAN)
    draw_dot_centered(special_bomb_corridor_x, SPECIAL_BOMB_ROW_Y, CYAN)
    draw_label(
        SPECIAL_BOMB_LABEL,
        points.new(special_bomb_corridor_x + LABEL_GAP, SPECIAL_BOMB_ROW_Y - 2),
        cyan_font
    )
end

local HINT_BLINK_DURATION = 0.6
local HINT_COOLDOWN_DURATION = 3.0
local HINT_BLINK_SEGMENT = 0.1

-- Mirror player_selection.tl's join-button check (LEFT/RIGHT).
local MOVEMENT_BUTTONS = {
    [joysticks.BUTTONS.LEFT] = true,
    [joysticks.BUTTONS.RIGHT] = true,
}

local function pressed_wrong_button(player_id: integer): boolean
    for button = 1, joysticks.MAX_BUTTONS do
        if not MOVEMENT_BUTTONS[button] and joysticks.is_pressed(player_id, button) then
            return true
        end
    end

    return false
end

-- Pressing wrong button to join gives feedback,
-- cooldown stops constant flashing and sounds if mashing buttons.
function ControllerHints:_watch_for_wrong_press()
    if self.hint_cooldown_time_left > 0 then
        return
    end

    for player_id = 1, joysticks.maxplayers() do
        if
            not self.player_info:has_cursor(player_id)
            and pressed_wrong_button(player_id)
        then
            self.hint_cooldown_time_left = HINT_COOLDOWN_DURATION
            wrong_input_sound:play()
            return
        end
    end
end

-- 0.6s of 0.1s on/off flashes for select character label if wrong button is used.
function ControllerHints:_select_label_font(): MenuFont
    local since_wrong_press = HINT_COOLDOWN_DURATION - self.hint_cooldown_time_left
    if since_wrong_press >= HINT_BLINK_DURATION then
        return white_font
    end

    local blink_segment = math.floor(since_wrong_press / HINT_BLINK_SEGMENT)
    if blink_segment % 2 == 0 then
        return red_font
    end

    return white_font
end

-- D-pad forks for the two contorller hints: select here, walk later in battle.
function ControllerHints:_draw_left_fork()
    draw_vline(LEFT_SPINE_X, SELECT_CHARACTER_BEND_Y, WALK_BEND_Y, WHITE)
    draw_hline(LEFT_SPINE_X, DPAD_BOX.x, DPAD_ROW_Y, WHITE)
    draw_dot_centered(LEFT_SPINE_X, SELECT_CHARACTER_BEND_Y, WHITE)
    draw_dot_centered(LEFT_SPINE_X, WALK_BEND_Y, WHITE)

    local select_label_font = self:_select_label_font()
    draw_label_right_aligned(
        SELECT_LABEL, LEFT_LABEL_RIGHT_EDGE, SELECT_ROW_Y, select_label_font
    )
    draw_label_right_aligned(
        CHARACTER_LABEL, LEFT_LABEL_RIGHT_EDGE, CHARACTER_ROW_Y, select_label_font
    )
    draw_label_right_aligned(WALK_LABEL, LEFT_LABEL_RIGHT_EDGE, WALK_ROW_Y, white_font)
end

function ControllerHints:_update_hint_timers(dt: number)
    self.hint_cooldown_time_left = math.max(self.hint_cooldown_time_left - dt, 0)
end

function ControllerHints:update(dt: number)
    self:_watch_for_wrong_press()
    self:_update_hint_timers(dt)
end

function ControllerHints:draw()
    fill_rect(
        self.hint_backdrop.x,
        self.hint_backdrop.y,
        self.hint_backdrop.width,
        self.hint_backdrop.height,
        BACKDROP_TINT,
        BACKDROP_ALPHA
    )
    lutro.graphics.draw(pad_image, PAD_POSITION.x, PAD_POSITION.y)
    draw_right_column()
    draw_special_bomb_line()
    self:_draw_left_fork()
end

return controller_hints
