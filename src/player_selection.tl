local animations = require("animations")
local audio = require("audio")
local characters = require("characters")
local fonts = require("fonts")
local game = require("game")
local joysticks = require("joysticks")
local menu_items = require("menus.items")
local scenes = require("scenes")
local vectors = require("geometry.vectors")
local points = require("geometry.points")


local record Character
   sprite: CharacterName
   number: integer
   y_shift: number
end

function Character.new(sprite: CharacterName, number: integer): Character
    local self: Character = setmetatable({}, { __index = Character })
    self.sprite = sprite
    self.number = number
    self.y_shift = 0.0
    return self
end

local JOYPAD = joysticks.buttons()
local FIRST_CHAR_POS = points.new(50, 50)
local ROW_OFFSET = vectors.new(23, 20)
local COLUMN_OFFSET = vectors.new(45, 0)

function Character:get_position(): Point
    local character_rows = 2

    -- Using 0 index for these integers:
    local character_number = self.number - 1
    local column = math.floor(character_number / character_rows)
    local row = math.fmod(character_number, character_rows)

    local pos_offset = ROW_OFFSET:scale(row):plus(COLUMN_OFFSET:scale(column))
    local walk_offset = vectors.new(0, self.y_shift)
    return FIRST_CHAR_POS:move(pos_offset):move(walk_offset)
end

function Character:walk(dt: number)
    local walk_speed = 5
    self.y_shift = self.y_shift + dt * walk_speed
end

local ok_sound: Source
local selector_indicator: Image
local background: Image
local black_font: MenuFont
local music: Source
local idle_down_images: {CharacterName: Image} = {}
local walk_down_images: {CharacterName: Image} = {}

local function get_idle_down_png(character_name: CharacterName): Image
    return lutro.graphics.newImage("assets/" .. character_name .. "/foot/idle_down.png")
end

local function get_walk_down_png(character_name: CharacterName): Image
    return lutro.graphics.newImage("assets/" .. character_name .. "/foot/walk_down.png")
end

local function get_walk_down_animation(character_name: CharacterName): Animation
    local image = walk_down_images[character_name]
    local animation = animations.new(image, 18, 34, 3, 6)
    animation.steps = animation.steps - 1 -- Skip final step when walking slowly
    return animation
end

local record PlayerSelection is Scene
    game: Game
    going_back_to_game: boolean
    player_selecting: integer
    idle_images: {integer: Image}
    slow_walk_animations: {CharacterName: Animation}
    selector: MenuSelection<integer>
    selectable_characters: {Character}
    walking_characters: {Character}
end

function PlayerSelection.new(): PlayerSelection
    local self: PlayerSelection = setmetatable({}, { __index = PlayerSelection })
    self.game = game.new(self)
    self.going_back_to_game = false
    self.idle_images = {}
    self.slow_walk_animations = {}
    self.selectable_characters = {}
    self.walking_characters = {}
    return self
end

function PlayerSelection:load()
    -- Entering scene we need to re-calculate these from game state
    self.player_selecting = self.game:pop_player_joining()
    assert(self.player_selecting, "Joined player selection scene but no is joining?")
    self.slow_walk_animations = {}
    self.selectable_characters = {}
    local previous_walk_state = self.walking_characters
    self.walking_characters = {}
    for idx, sprite in ipairs(characters.get_names()) do
        local character = Character.new(sprite, idx)
        if characters.is_unused(sprite) then
            table.insert(self.selectable_characters, character)
        else
            table.insert(self.walking_characters, character)
        end
        self.slow_walk_animations[sprite] = get_walk_down_animation(sprite)
    end

    for _, old_walking in ipairs(previous_walk_state) do
        for _, new_walking in ipairs(self.walking_characters) do
            if old_walking.number == new_walking.number then
                new_walking.y_shift = old_walking.y_shift
            end
        end
    end

    self.selector = menu_items.new_integer_selection(1, 1, #self.selectable_characters)
end

local player_selection = {}

function player_selection.load_assets()
    for _, sprite in ipairs(characters.get_names()) do
        idle_down_images[sprite] = get_idle_down_png(sprite)
        walk_down_images[sprite] = get_walk_down_png(sprite)
    end

    selector_indicator = lutro.graphics.newImage("assets/player_indicator.png")
    background = lutro.graphics.newImage("assets/grass.png")

    ok_sound = menu_items.ok_sound()
    black_font = fonts.new_menu_black()
    music = audio.new_source("assets/music/player-selection.ogg", "static")
    music:setVolume(0.75)
end

function PlayerSelection:handle_player_input()    
    local ok_action = false
    
    if joysticks.is_pressed(self.player_selecting, JOYPAD.RIGHT) then
        ok_action = self.selector:increment()
    elseif joysticks.is_pressed(self.player_selecting, JOYPAD.LEFT) then
        ok_action = self.selector:decrement()
    elseif (joysticks.is_pressed(self.player_selecting, JOYPAD.B) or 
            joysticks.is_pressed(self.player_selecting, JOYPAD.R)) then

        local selected = table.remove(self.selectable_characters, self.selector:get_value())
        table.insert(self.walking_characters, selected)
        characters.new_selection(self.player_selecting, selected.sprite)
        self.selector:reduce_max_val()

        ok_action = true
        self.player_selecting = self.game:pop_player_joining()
    end

    if ok_action then
        ok_sound:play()
    end

    if not self.player_selecting then
        music:stop()
        self.game:update_players()
        scenes.set(self.game, self.going_back_to_game)
        if self.going_back_to_game then
            -- The game might have paused audio, make sure to unpause:
            audio.unpause()
        end
        -- Game started, keep track on that state:
        self.going_back_to_game = true
    end
end

function PlayerSelection:update(dt: number)
    if not music:isPlaying() then
        music:play()
    end

    self:handle_player_input()

    for _, selected in ipairs(self.walking_characters) do
        selected:walk(dt)
        self.slow_walk_animations[selected.sprite]:update(dt)
    end
end

function PlayerSelection:draw_idle(character: Character)
    local pos = character:get_position()
    lutro.graphics.draw(idle_down_images[character.sprite], pos.x, pos.y)
end

function PlayerSelection:draw_slow_walking(character: Character)
    local pos = character:get_position()
    self.slow_walk_animations[character.sprite]:draw(pos.x, pos.y)
end

function PlayerSelection:draw()
	lutro.graphics.draw(background)

    for _, char in ipairs(self.selectable_characters) do
        self:draw_idle(char)
    end
    for _, char in ipairs(self.walking_characters) do
        self:draw_slow_walking(char)
    end

    local character = self.selectable_characters[self.selector:get_value()]
    local indicator_offset = vectors.new(4, -5)
    local indicator_pos = character:get_position():move(indicator_offset)
    lutro.graphics.draw(selector_indicator, indicator_pos.x, indicator_pos.y)

    local indicator_text = tostring(self.player_selecting)
    local indicator_text_offset = vectors.new(0, 3)
    local text_pos = indicator_pos:move(indicator_text_offset)
    local text_box = selector_indicator:getWidth()
    black_font:print_centered(indicator_text, text_box, text_pos)
end

function player_selection.setup(): Scene
	return PlayerSelection.new()
end

return player_selection
