local audio = require("audio")
local const = require("const")
local fonts = require("fonts")
local joysticks = require("joysticks")
local points = require("geometry.points")
local rectangles = require("geometry.rectangles")
local scenes = require("scenes")


local JOYPAD = joysticks.buttons()
local GAME_EXIT_TIME = 5
local pause_menu_image: Image
local pause_menu_sound: Source
local white_font: MenuFont
local game_pause = {}

local record GamePause is Scene
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
        (const.MAP_WIDTH - width) / 2,
        (const.MAP_HEIGHT - height) / 2,
        width,
        height
    )
end

function game_pause.new(
    paused_scene: Scene,
    player_id: integer,
    is_playing: boolean,
    toggle_if_playing: function(integer)
): GamePause
    local self: GamePause = setmetatable({}, { __index = GamePause })
    self.paused_scene = paused_scene
    self.player_id = player_id
    self.is_playing = is_playing
    self.exit_counter = 0
    self.toggle_if_playing = toggle_if_playing

    pause_menu_sound:play()
    return self
end

local function set_alpha_for_image(image: Image, alpha: number)
    local image_data = image:getData()
	for i = 0, image:getWidth() - 1 do
		for j = 0, image:getHeight() - 1 do
			local r, g, b, _ = image_data:getPixel(i, j)	
            image_data:setPixel(i, j, r, g, b, alpha)
		end
	end
end

function game_pause.load_assets()
    white_font = fonts.new_menu_white()
    pause_menu_image = lutro.graphics.newImage("assets/pause-menu.png")
    pause_menu_sound = audio.new_source("assets/pause.wav", "static")
    set_alpha_for_image(pause_menu_image, 225)
end

function GamePause:_time_to_exit(): integer
    return math.floor(GAME_EXIT_TIME - self.exit_counter)
end

function GamePause:draw()
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

function GamePause:update(dt: number)
	if joysticks.is_pressed(self.player_id, JOYPAD.START) then
        audio.unpause()
		scenes.set(self.paused_scene, true)
	end
    if joysticks.is_pressed(self.player_id, JOYPAD.L) then
        self.toggle_if_playing(self.player_id)
    end
    if lutro.joystick.isDown(self.player_id, JOYPAD.SELECT) then
        self.exit_counter = self.exit_counter + dt
    else
        self.exit_counter = 0
    end
    if self:_time_to_exit() == 0 then
        audio.stop()
        scenes.return_to_start()
    end
end

return game_pause
