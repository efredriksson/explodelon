local characters = require("characters")
local audio = require("engine.audio")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local screen = require("screen")

local type MenuFont = fonts.MenuFont
local type Point = points.Point
local type Scene = scenes.Scene
local type Rectangle = rectangles.Rectangle

local interface PausedGame is Scene
    leave_game: function(self, player_id: integer)
    add_player: function(self)
end

local GAME_EXIT_TIME = 3.5
local pause_menu_image: Image
local pause_menu_sound: Source
local white_font: MenuFont
local pause_scene = {PausedGame = PausedGame}

local record GamePauseScene is Scene
    paused_game: PausedGame
    player_id: integer
    exit_counter: number
end

local function get_pause_square(): Rectangle
    local height = 50
    local width = 180
    return rectangles.new(
        (screen.WIDTH - width) / 2, (screen.HEIGHT - height) / 2, width, height
    )
end

local WINDOW = get_pause_square()
local FIRST_ROW_Y = 6
local ROW_HEIGHT = 10

local function row_position(row: integer): Point
    return points.new(WINDOW.x, WINDOW.y + FIRST_ROW_Y + ROW_HEIGHT * (row - 1))
end

-- Four rows is what the panel holds: below the last one is its bottom border.
local ROW_POSITIONS: {Point} = {
    row_position(1),
    row_position(2),
    row_position(3),
    row_position(4),
}

function pause_scene.new(paused_game: PausedGame, player_id: integer): GamePauseScene
    local self: GamePauseScene = setmetatable({}, {__index = GamePauseScene})
    self.paused_game = paused_game
    self.player_id = player_id
    self.exit_counter = 0

    pause_menu_sound:play()
    return self
end

function pause_scene.load_assets()
    white_font = fonts.new_menu_white()
    pause_menu_image = lutro.graphics.newImage("assets/pause-menu.png")
    pause_menu_sound = audio.new_source("assets/pause.wav", "static")
    images.set_alpha(pause_menu_image, 225)
end

function GamePauseScene:_time_to_exit(): integer
    return math.floor(GAME_EXIT_TIME - self.exit_counter)
end

function GamePauseScene:_is_playing(): boolean
    return characters.exist_selection_for(self.player_id)
end

function GamePauseScene:_exit_message(): string
    if self.exit_counter < 0.1 then
        return "hold select down to exit"
    else
        return "exiting game in " .. self:_time_to_exit()
    end
end

function GamePauseScene:_print_row(text: string, row: integer)
    white_font:print_centered(text, WINDOW.width, ROW_POSITIONS[row])
end

function GamePauseScene:draw()
    self.paused_game:draw()
    lutro.graphics.draw(pause_menu_image, WINDOW.x, WINDOW.y)

    self:_print_row("game paused by player " .. self.player_id, 1)
    self:_print_row("press r1 to add players", 2)
    if self:_is_playing() then
        self:_print_row("press l1 to leave", 3)
    end
    self:_print_row(self:_exit_message(), 4)
end

function GamePauseScene:update(dt: number)
    if joysticks.is_pressed(self.player_id, joysticks.BUTTONS.START) then
        scenes.set(self.paused_game, true)
    end
    if joysticks.is_pressed(self.player_id, joysticks.BUTTONS.R) then
        self.paused_game:add_player()
    end
    if
        self:_is_playing() and joysticks.is_pressed(self.player_id, joysticks.BUTTONS.L)
    then
        self.paused_game:leave_game(self.player_id)
    end
    if lutro.joystick.isDown(self.player_id, joysticks.BUTTONS.SELECT) then
        self.exit_counter = self.exit_counter + dt
    else
        self.exit_counter = 0
    end
    if self:_time_to_exit() == 0 then
        audio.stop()
        scenes.return_to_start()
    end
end

return pause_scene
