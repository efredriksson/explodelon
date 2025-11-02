local audio = require("audio")
local const = require("const")
local fonts = require("fonts")
local points = require("geometry.points")
local rectangles = require("geometry.rectangles")
local scenes = require("scenes")
local joysticks = require("joysticks")


local JOYPAD = joysticks.buttons()
local pause_menu_image: Image
local white_font: MenuFont
local game_pause = {}

local record GamePause is Scene
    paused_scene: Scene
    player_id: integer
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

function game_pause.new(paused_scene: Scene, player_id: integer): GamePause
    local self: GamePause = setmetatable({}, { __index = GamePause })
    self.paused_scene = paused_scene
    self.player_id = player_id
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
    set_alpha_for_image(pause_menu_image, 225)
end

function GamePause:draw()
	self.paused_scene:draw()
    local window = get_pause_square()
    lutro.graphics.draw(pause_menu_image, window.x, window.y)
    local text_pos = points.new(window.x, window.y + 10)
    white_font:print_centered("game paused by player " .. self.player_id, window.width, text_pos)
end

function GamePause:update(_: number)
	if joysticks.is_pressed(self.player_id, JOYPAD.START) then
        audio.unpause()
		scenes.set(self.paused_scene, false)
	end
end

return game_pause
