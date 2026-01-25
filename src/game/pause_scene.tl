local audio = require("engine.audio")
local fonts = require("fonts")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local points = require("engine.geometry.points")
local rectangles = require("engine.geometry.rectangles")
local scenes = require("engine.scenes")
local screen = require("screen")

local type MenuFont = fonts.MenuFont 
local type Scene = scenes.Scene
local type Rectangle = rectangles.Rectangle

local GAME_EXIT_TIME = 3.5
local pause_menu_image: Image
local pause_menu_sound: Source
local white_font: MenuFont
local pause_scene = {}

local record GamePauseScene is Scene
    paused_scene: Scene
    player_id: integer
    is_playing: boolean
    exit_counter: number
    toggle_if_playing: function(integer)
end

local function get_pause_square(): Rectangle
    local height = 50
    local width = 180
    return rectangles.new(
        (screen.WIDTH - width) / 2,
        (screen.HEIGHT - height) / 2,
        width,
        height
    )
end

function pause_scene.new(
    paused_scene: Scene,
    player_id: integer,
    is_playing: boolean,
    toggle_if_playing: function(integer)
): GamePauseScene
    local self: GamePauseScene = setmetatable({}, { __index = GamePauseScene })
    self.paused_scene = paused_scene
    self.player_id = player_id
    self.is_playing = is_playing
    self.exit_counter = 0
    self.toggle_if_playing = toggle_if_playing

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

function GamePauseScene:draw()
	self.paused_scene:draw()
    local window = get_pause_square()
    lutro.graphics.draw(pause_menu_image, window.x, window.y)
    local header_pos = points.new(window.x, window.y + 10)
    white_font:print_centered(
        "game paused by player " .. self.player_id, window.width, header_pos
    )

    local toggle_msg_pos = points.new(window.x, window.y + 22)
    if not self.is_playing then
        white_font:print_centered("press l1 to join", window.width, toggle_msg_pos)
    else
        white_font:print_centered("press l1 to leave", window.width, toggle_msg_pos)
    end

    local exit_msg_pos = points.new(window.x, window.y + 34)
    if self.exit_counter < 0.1 then
        white_font:print_centered("hold select down to exit", window.width, exit_msg_pos)
    else
        white_font:print_centered("exiting game in " .. self:_time_to_exit(), window.width, exit_msg_pos)
    end
end

function GamePauseScene:update(dt: number)
	if joysticks.is_pressed(self.player_id, joysticks.BUTTONS.START) then
		scenes.set(self.paused_scene, true)
	end
    if joysticks.is_pressed(self.player_id, joysticks.BUTTONS.L) then
        self.toggle_if_playing(self.player_id)
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
