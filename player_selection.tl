local animations = require("animations")
local geometry = require("geometry")
local scenes = require("scenes")
local fonts = require("fonts")
local menu_items = require("menu_items")
local joysticks = require("joysticks")
local character_sprites = require("character_sprites")
local game = require("game")

local record Character
   sprite: CharacterSprite
   number: integer
   y_shift: number
end

function Character.new(sprite: CharacterSprite, number: integer): Character
    local self: Character = setmetatable({}, { __index = Character })
    self.sprite = sprite
    self.number = number
    self.y_shift = 0.0
    return self
end

local JOYPAD = joysticks.buttons()
local FIRST_CHAR_POS = geometry.new_point(50, 50)
local ROW_OFFSET = geometry.new_vector(23, 20)
local COLUMN_OFFSET = geometry.new_vector(45, 0)

function Character:get_position(): Point
    local character_rows = 2

    -- Using 0 index for these integers:
    local character_number = self.number - 1
    local column = math.floor(character_number / character_rows)
    local row = math.fmod(character_number, character_rows)

    local pos_offset = ROW_OFFSET:scale(row):plus(COLUMN_OFFSET:scale(column))
    local walk_offset = geometry.new_vector(0, self.y_shift)
    return FIRST_CHAR_POS:move(pos_offset):move(walk_offset)
end

function Character:walk(dt: number)
    local walk_speed = 5
    self.y_shift = self.y_shift + dt * walk_speed
end

-- TODO: Move these into the scene object
local player_selecting = 1
local number_players_selecting: integer
local ok_sound: Source
local idle_images: {integer: Image} = {}
local slow_walk_animations: {integer: Animation} = {}
local selector_indicator: Image
local background: Image
local black_font: MenuFont
local selector = menu_items.new_selection(1, 1, 10)
local selected_characters: {Character} = {}
local selectable_characters: {Character} = {}

local function get_idle_down_png(character_name: string): Image
    return lutro.graphics.newImage("assets/" .. character_name .. "/foot/idle_down.png")
end

local function get_walk_down_animation(character_name: string): Animation
    local image = lutro.graphics.newImage("assets/" .. character_name .. "/foot/walk_down.png")
    local animation = animations.new(image, 18, 34, 3, 6)
    animation.steps = animation.steps - 1 -- Skip final step when walking slowly
    return animation
end

local record PlayerSelection is Scene
end

function PlayerSelection.new(): PlayerSelection
   local self: PlayerSelection = setmetatable({}, { __index = PlayerSelection })
   return self
end

function PlayerSelection:load()
    for idx, sprite in ipairs(character_sprites.get()) do
        table.insert(selectable_characters, Character.new(sprite, idx))
    end

    for _, char in ipairs(selectable_characters) do
        idle_images[char.number] = get_idle_down_png(char.sprite)
        slow_walk_animations[char.number] = get_walk_down_animation(char.sprite)
    end

    selector_indicator = lutro.graphics.newImage("assets/player_indicator.png")
    background = lutro.graphics.newImage("assets/grass.png")

    ok_sound = menu_items.ok_sound()
    black_font = fonts.new_menu_black()
end

local function handle_player_input()
    local ok_action = false
    
    if joysticks.is_pressed(player_selecting, JOYPAD.RIGHT) then
        ok_action = selector:increment()
    elseif joysticks.is_pressed(player_selecting, JOYPAD.LEFT) then
        ok_action = selector:decrement()
    elseif (joysticks.is_pressed(player_selecting, JOYPAD.B) or 
            joysticks.is_pressed(player_selecting, JOYPAD.R)) then

        local selected = table.remove(selectable_characters, selector.value)
        table.insert(selected_characters, selected)
        selector:reduce_max_val()

        ok_action = true
        player_selecting = player_selecting + 1
    end

    if ok_action then
        lutro.audio.play(ok_sound)
    end

    if player_selecting > number_players_selecting then
        local selected_sprites: {CharacterSprite} = {}
        for _, selected in ipairs(selected_characters) do
            table.insert(selected_sprites, selected.sprite)
        end 
        scenes.set(game.setup(selected_sprites))
    end
end

function PlayerSelection:update(dt: number)
    handle_player_input()

    for _, selected in ipairs(selected_characters) do
        selected:walk(dt)
        slow_walk_animations[selected.number]:update(dt)
    end
end

local function draw_idle(character: Character)
    local pos = character:get_position()
    lutro.graphics.draw(idle_images[character.number], pos.x, pos.y)
end

local function draw_slow_walking(character: Character)
    local pos = character:get_position()
    slow_walk_animations[character.number]:draw(pos.x, pos.y)
end

function PlayerSelection:draw()
	lutro.graphics.draw(background)

    for _, char in ipairs(selectable_characters) do
        draw_idle(char)
    end
    for _, char in ipairs(selected_characters) do
        draw_slow_walking(char)
    end

    local character = selectable_characters[selector.value]
    local indicator_offset = geometry.new_vector(4, -5)
    local indicator_pos = character:get_position():move(indicator_offset)
    lutro.graphics.draw(selector_indicator, indicator_pos.x, indicator_pos.y)

    local indicator_text = tostring(player_selecting)
    local indicator_text_offset = geometry.new_vector(0, 3)
    local text_pos = indicator_pos:move(indicator_text_offset)
    local text_box = selector_indicator:getWidth()
    black_font:print_centered(indicator_text, text_box, text_pos)
end

local player_selection = {}

function player_selection.setup(number_players: integer): Scene
    number_players_selecting = number_players
	return PlayerSelection.new()
end

return player_selection
