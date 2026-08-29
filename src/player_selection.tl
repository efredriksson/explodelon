local characters = require("characters")
local animations = require("engine.animations")
local audio = require("engine.audio")
local points = require("engine.geometry.points")
local vectors = require("engine.geometry.vectors")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local battle = require("game.battle")
local score_board = require("game.score_board")
local win_condition = require("game.win_condition")
local itertools = require("itertools")
local controller_hints = require("menus.controller_hints")
local items = require("menus.items")
local screen = require("screen")
local settings = require("settings")
local team_selection = require("team_selection")

local type Animation = animations.Animation
local type Battle = battle.Battle
local type SinglesScoreBoard = score_board.SinglesScoreBoard
local type CharacterName = characters.CharacterName
local type CharacterSelection = characters.CharacterSelection
local type ControllerHints = controller_hints.ControllerHints
local type MenuFont = fonts.MenuFont
local type Scene = scenes.Scene
local type Point = points.Point
local type PlayerInfo = controller_hints.PlayerInfo

local COUNTDOWN_DURATION = 3.0

local record Character
    sprite: CharacterName
    number: integer
    y_shift: number
end

function Character.new(sprite: CharacterName, number: integer): Character
    local self: Character = setmetatable({}, {__index = Character})
    self.sprite = sprite
    self.number = number
    self.y_shift = 0.0
    return self
end

local FIRST_CHAR_POS = points.new(50, 50)
local ROW_OFFSET = vectors.new(23, 20)
local COLUMN_OFFSET = vectors.new(45, 0)

function Character:get_position(): Point
    local character_rows = 2

    local zero_based_number = self.number - 1
    local column = math.floor(zero_based_number / character_rows)
    local row = math.fmod(zero_based_number, character_rows)

    local pos_offset = ROW_OFFSET:scale(row):plus(COLUMN_OFFSET:scale(column))
    local walk_offset = vectors.new(0, self.y_shift)
    return FIRST_CHAR_POS:move(pos_offset):move(walk_offset)
end

function Character:is_taken(): boolean
    return not characters.is_unused(self.sprite)
end

-- Walking stops before the character leaves the line-up and takes its player
-- number off screen with it.
local WALK_DISTANCE = 56
local WALK_SPEED = 5

function Character:is_walking(): boolean
    return self:is_taken() and self.y_shift < WALK_DISTANCE
end

function Character:update(dt: number)
    if not self:is_taken() then
        self.y_shift = 0.0
    elseif self:is_walking() then
        self.y_shift = math.min(self.y_shift + dt * WALK_SPEED, WALK_DISTANCE)
    end
end

-- arrival_order lets several cursors sharing one character be stacked in the
-- order they arrived.
local record Cursor
    player_id: integer
    character_number: integer
    arrival_order: integer
    confirmed: boolean
end

function Cursor.new(
    player_id: integer, character_number: integer, arrival_order: integer
): Cursor
    local self: Cursor = setmetatable({}, {__index = Cursor})
    self.player_id = player_id
    self.character_number = character_number
    self.arrival_order = arrival_order
    self.confirmed = false
    return self
end

local ok_sound: Source
local selector_indicator: Image
local background: Image
local black_font: MenuFont
local white_font: MenuFont
local music: Source
local idle_down_images: {CharacterName: Image} = {}
local slow_walk_animations: {CharacterName: Animation} = {}

local function get_idle_down_png(character_name: CharacterName): Image
    return lutro.graphics.newImage("assets/" .. character_name .. "/foot/idle_down.png")
end

local function get_walk_down_png(character_name: CharacterName): Image
    return lutro.graphics.newImage("assets/" .. character_name .. "/foot/walk_down.png")
end

local function get_walk_down_animation(character_name: CharacterName): Animation
    local image = get_walk_down_png(character_name)
    local animation = animations.new(image, 18, 0.5)
    animation.steps = animation.steps - 1 -- Skip final step when walking slowly
    return animation
end

local record PlayerSelection is Scene, PlayerInfo
    game: Battle
    score_board: SinglesScoreBoard
    team_selection: Scene
    going_back_to_game: boolean
    cursors: {Cursor}
    next_arrival_order: integer
    countdown_time: number
    line_up: {Character}
    controller_hints: ControllerHints
end

function PlayerSelection.new(): PlayerSelection
    local self: PlayerSelection = setmetatable({}, {__index = PlayerSelection})
    self.score_board = score_board.new_for_singles()
    self.game = battle.new(
        self, self.score_board, win_condition.new_for_singles(self.score_board)
    )
    self.team_selection = team_selection.new(self, music)
    self.going_back_to_game = false
    self.cursors = {}
    self.next_arrival_order = 1
    self.countdown_time = COUNTDOWN_DURATION
    self.line_up = {}
    for number, sprite in ipairs(characters.get_names()) do
        table.insert(self.line_up, Character.new(sprite, number))
    end
    self.controller_hints = controller_hints.new(self)
    return self
end

function PlayerSelection:_skips_lobby(): boolean
    return settings.auto_select_characters
end

function PlayerSelection:_countdown_duration(): number
    if self:_skips_lobby() then
        return 0
    else
        return COUNTDOWN_DURATION
    end
end

function PlayerSelection:_character_number_of(sprite: CharacterName): integer
    for _, character in ipairs(self.line_up) do
        if character.sprite == sprite then
            return character.number
        end
    end

    return nil
end

function PlayerSelection:_next_arrival_order(): integer
    local order = self.next_arrival_order
    self.next_arrival_order = order + 1
    return order
end

-- Existing selections come back as confirmed cursors: a rematch is then just
-- holding start again, and reopening mid-battle shows who's still playing.
function PlayerSelection:_initial_cursors(): {Cursor}
    local function cursor_for(selection: CharacterSelection): Cursor
        local cursor = Cursor.new(
            selection.player_id,
            self:_character_number_of(selection.sprite),
            self:_next_arrival_order()
        )
        cursor.confirmed = true
        return cursor
    end

    return itertools.map(characters.get_selections(), cursor_for)
end

local player_selection = {}

function player_selection.load_assets()
    for _, sprite in ipairs(characters.get_names()) do
        idle_down_images[sprite] = get_idle_down_png(sprite)
        slow_walk_animations[sprite] = get_walk_down_animation(sprite)
    end

    selector_indicator = lutro.graphics.newImage("assets/player_indicator.png")
    background = lutro.graphics.newImage("assets/grass.png")

    ok_sound = items.ok_sound()
    black_font = fonts.new_menu_black()
    white_font = fonts.new_menu_white_outlined()
    music = audio.new_source("assets/music/player-selection.ogg", "static")
    music:setLooping(true)
    music:setVolume(0.75)

    controller_hints.load_assets()
end

function PlayerSelection:has_cursor(player_id: integer): boolean
    for _, cursor in ipairs(self.cursors) do
        if cursor.player_id == player_id then
            return true
        end
    end

    return false
end

function PlayerSelection:_may_activate(player_id: integer): boolean
    return not self:has_cursor(player_id)
        and not characters.exist_selection_for(player_id)
end

function PlayerSelection:_is_pointed_at(character: Character): boolean
    for _, cursor in ipairs(self.cursors) do
        if cursor.character_number == character.number then
            return true
        end
    end

    return false
end

local function is_free(character: Character): boolean
    return not character:is_taken()
end

-- Start a new player off on a character nobody else is looking at, so two
-- freshly activated controllers do not stack up on the same sprite.
function PlayerSelection:_character_to_activate_on(): Character
    local function is_unattended(character: Character): boolean
        return not self:_is_pointed_at(character)
    end

    local free_characters = itertools.filter(self.line_up, is_free)
    local unattended_characters = itertools.filter(free_characters, is_unattended)
    return unattended_characters[1] or free_characters[1]
end

function PlayerSelection:_activate_cursor_for(player_id: integer): boolean
    local character = self:_character_to_activate_on()
    if not character then
        return false
    end

    table.insert(
        self.cursors,
        Cursor.new(player_id, character.number, self:_next_arrival_order())
    )
    return true
end

function PlayerSelection:load()
    if self:_skips_lobby() then
        characters.set_auto_selected(settings.number_of_auto_selected_characters)
    end

    self.countdown_time = self:_countdown_duration()
    self.next_arrival_order = 1
    self.cursors = self:_initial_cursors()
end

function PlayerSelection:_activate_new_cursors(): boolean
    local activated = false
    for player_id = 1, joysticks.maxplayers() do
        local trying_to_select = joysticks.is_pressed(
            player_id, joysticks.BUTTONS.RIGHT
        ) or joysticks.is_pressed(player_id, joysticks.BUTTONS.LEFT)

        if trying_to_select and self:_may_activate(player_id) then
            if self:_activate_cursor_for(player_id) then
                activated = true
            end
        end
    end

    return activated
end

function PlayerSelection:_free_character_number(from: integer, step: integer): integer
    local number = from + step
    while self.line_up[number] do
        if not self.line_up[number]:is_taken() then
            return number
        end
        number = number + step
    end

    return nil
end

function PlayerSelection:_move_cursor(cursor: Cursor, step: integer): boolean
    local number = self:_free_character_number(cursor.character_number, step)
    if not number then
        return false
    end

    cursor.character_number = number
    cursor.arrival_order = self:_next_arrival_order()
    return true
end

-- A cursor still pointing at a sprite that gets taken steps aside to the next
-- character, the same move it would have made on its own.
function PlayerSelection:_move_cursors_off_taken_characters()
    for _, cursor in ipairs(self.cursors) do
        if not cursor.confirmed then
            local character = self.line_up[cursor.character_number]
            if character:is_taken() then
                local stepped_right = self:_move_cursor(cursor, 1)
                if not stepped_right then
                    self:_move_cursor(cursor, -1)
                end
            end
        end
    end
end

function PlayerSelection:_confirm(cursor: Cursor): boolean
    local character = self.line_up[cursor.character_number]
    if character:is_taken() then
        return false
    end

    characters.new_selection(cursor.player_id, character.sprite)
    cursor.confirmed = true
    self:_move_cursors_off_taken_characters()
    return true
end

function PlayerSelection:_handle_cursor_input(cursor: Cursor): boolean
    local player_id = cursor.player_id

    if cursor.confirmed then
        if joysticks.is_pressed(player_id, joysticks.BUTTONS.A) then
            characters.remove_selection_for(player_id)
            cursor.confirmed = false
            return true
        end

        return false
    end

    if joysticks.is_pressed(player_id, joysticks.BUTTONS.RIGHT) then
        return self:_move_cursor(cursor, 1)
    elseif joysticks.is_pressed(player_id, joysticks.BUTTONS.LEFT) then
        return self:_move_cursor(cursor, -1)
    elseif (
        joysticks.is_pressed(player_id, joysticks.BUTTONS.B)
        or joysticks.is_pressed(player_id, joysticks.BUTTONS.R)
    ) then
        return self:_confirm(cursor)
    end

    return false
end

-- Leaving is only offered to players still making up their mind; a picked
-- character is given back with A instead.
function PlayerSelection:_deactivate_cursors(): boolean
    local deactivated = false
    for i = #self.cursors, 1, -1 do
        local cursor = self.cursors[i]
        local wants_to_leave = joysticks.is_pressed(
            cursor.player_id, joysticks.BUTTONS.A
        )
        if not cursor.confirmed and wants_to_leave then
            table.remove(self.cursors, i)
            deactivated = true
        end
    end

    return deactivated
end

-- Leaving and picking are settled before new controllers are let in, so the
-- press that activates a player does not also move their brand new cursor.
function PlayerSelection:_handle_player_input()
    local ok_action = self:_deactivate_cursors()

    for _, cursor in ipairs(self.cursors) do
        if self:_handle_cursor_input(cursor) then
            ok_action = true
        end
    end

    if self:_activate_new_cursors() then
        ok_action = true
    end

    if ok_action then
        ok_sound:play()
    end
end

function PlayerSelection:_is_someone_holding_start(): boolean
    for _, cursor in ipairs(self.cursors) do
        local holding_start = lutro.joystick.isDown(
            cursor.player_id, joysticks.BUTTONS.START
        )
        if cursor.confirmed and holding_start then
            return true
        end
    end

    return false
end

function PlayerSelection:_has_enough_players(): boolean
    return #characters.get_selections() >= settings.MINIMUM_PLAYERS
end

function PlayerSelection:_is_starting(): boolean
    if self:_skips_lobby() then
        return true
    end

    return self:_has_enough_players() and self:_is_someone_holding_start()
end

function PlayerSelection:_start_battle()
    if settings.teams then
        scenes.set(self.team_selection)
        return
    end

    music:stop()
    self.score_board:update_avatars(characters.get_selections())
    self.game:enter(self.going_back_to_game)
    self.going_back_to_game = true
end

function PlayerSelection:_update_countdown(dt: number, is_starting: boolean)
    if is_starting then
        self.countdown_time = math.max(self.countdown_time - dt, 0)
    else
        self.countdown_time = self:_countdown_duration()
    end
end

-- A skipped lobby lives for a single frame, which is still long enough to start
-- the music over the battle it is about to hand back to.
function PlayerSelection:_keep_music_playing()
    if self:_skips_lobby() or music:isPlaying() then
        return
    end

    music:play()
end

function PlayerSelection:update(dt: number)
    self:_keep_music_playing()

    self.controller_hints:update(dt)
    self:_handle_player_input()

    local is_starting = self:_is_starting()
    self:_update_countdown(dt, is_starting)

    if is_starting and self.countdown_time == 0 then
        self:_start_battle()
        return
    end

    for _, character in ipairs(self.line_up) do
        character:update(dt)
        if character:is_walking() then
            slow_walk_animations[character.sprite]:update(dt)
        end
    end
end

local INDICATOR_OFFSET = vectors.new(4, -5)
local INDICATOR_TEXT_OFFSET = vectors.new(0, 3)
local MESSAGE_POSITION = points.new(0, 10)
local NOT_ENOUGH_PLAYERS_MESSAGE = settings.MINIMUM_PLAYERS .. " players needed"

-- Indicators stack a full height apart so the player numbers stay readable;
-- the newest arrival sits on top.
function PlayerSelection:_indicators_below(cursor: Cursor): integer
    local function arrived_earlier_on_same_character(other: Cursor): boolean
        return other.character_number == cursor.character_number
            and other.arrival_order < cursor.arrival_order
    end

    return itertools.count(self.cursors, arrived_earlier_on_same_character)
end

function PlayerSelection:_draw_indicator(cursor: Cursor, character_position: Point)
    local stack_height = selector_indicator:getHeight() * self:_indicators_below(cursor)
    local stack_offset = vectors.new(0, -stack_height)
    local indicator_pos = character_position:move(INDICATOR_OFFSET):move(stack_offset)
    lutro.graphics.draw(selector_indicator, indicator_pos.x, indicator_pos.y)

    local text_pos = indicator_pos:move(INDICATOR_TEXT_OFFSET)
    local text_box = selector_indicator:getWidth()
    black_font:print_centered(tostring(cursor.player_id), text_box, text_pos)
end

function PlayerSelection:_going_word(): string
    if self.going_back_to_game then
        return "resume"
    else
        return "begin"
    end
end

function PlayerSelection:_hold_start_message(): string
    return "hold start to " .. self:_going_word()
end

-- The countdown only moves while someone holds start, so its value alone says
-- whether anyone is.
function PlayerSelection:_start_message(): string
    if not self:_has_enough_players() then
        return NOT_ENOUGH_PLAYERS_MESSAGE
    elseif self.countdown_time < COUNTDOWN_DURATION then
        return self:_going_word() .. " in " .. math.ceil(self.countdown_time)
    else
        return self:_hold_start_message()
    end
end

function PlayerSelection:_draw_start_message()
    white_font:print_centered(self:_start_message(), screen.WIDTH, MESSAGE_POSITION)
end

function PlayerSelection:_draw_character(character: Character)
    local position = character:get_position()
    if character:is_walking() then
        slow_walk_animations[character.sprite]:draw(position.x, position.y)
    else
        lutro.graphics.draw(idle_down_images[character.sprite], position.x, position.y)
    end

    for _, cursor in ipairs(self.cursors) do
        if cursor.character_number == character.number then
            self:_draw_indicator(cursor, position)
        end
    end
end

function PlayerSelection:draw()
    lutro.graphics.draw(background)

    for _, character in ipairs(self.line_up) do
        self:_draw_character(character)
    end

    self:_draw_start_message()
    self.controller_hints:draw()
end

function player_selection.setup(): Scene
    return PlayerSelection.new()
end

return player_selection
