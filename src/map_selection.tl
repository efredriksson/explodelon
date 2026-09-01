local audio = require("engine.audio")
local points = require("engine.geometry.points")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local itertools = require("itertools")
local level_graphics = require("level_graphics.maps.init")
local map_preview = require("map_preview.init")
local items = require("menus.items")
local player_selection = require("player_selection")
local screen = require("screen")
local settings = require("settings")

local type Map = settings.Map
local type MapPreview = require("map_preview.interfaces")
local type MenuFont = fonts.MenuFont
local type MenuSelection = items.MenuSelection
local type Scene = scenes.Scene

local MAP_ORDER <total>: {Map: integer} = {
    football = 1,
    factory = 2,
    ice_rink = 3,
    bouncing = 4,
}

local function maps_in_cycle_order(): {Map}
    local ordered: {Map} = {}
    for map, position in pairs(MAP_ORDER) do
        ordered[position] = map
    end
    return ordered
end

local MAPS = maps_in_cycle_order()

local ARROW_MARGIN = 6

-- Centre the arrows in the screen below the map-name strip rather than the whole
-- screen, so they do not ride up into it.
local ARROW_AREA_TOP = 10

-- Centred on the blue info strip baked into the top of every map background.
local NAME_POSITION = points.new(0, 7)

local font: MenuFont
local ok_sound: Source
local arrow_left_image: Image
local arrow_right_image: Image
local arrow_shade_left_image: Image
local arrow_shade_right_image: Image

local record MapSelection is Scene
    previous_screen: Scene
    selection: MenuSelection<Map>
    preview: MapPreview
end

local map_selection = {}

function map_selection.new(previous_screen: Scene): MapSelection
    local self: MapSelection = setmetatable({}, {__index = MapSelection})
    self.previous_screen = previous_screen
    self.selection = items.new_enum(MAPS)
    self.preview = nil
    return self
end

function map_selection.load_assets()
    font = fonts.new_menu_white_outlined()
    ok_sound = items.ok_sound()
    arrow_right_image = lutro.graphics.newImage("assets/arrow_right.png")
    arrow_left_image = lutro.graphics.newImage("assets/arrow_right.png")
    images.flip_horizontal(arrow_left_image)
    arrow_shade_left_image = lutro.graphics.newImage("assets/arrow_shade.png")
    arrow_shade_right_image = lutro.graphics.newImage("assets/arrow_shade.png")
    images.flip_horizontal(arrow_shade_right_image)
end

-- leave() restores the global settings.map the preview swapped to "factory".
function MapSelection:_close_preview()
    if self.preview then
        self.preview:leave()
        self.preview = nil
    end
end

function MapSelection:load()
    self:_close_preview()
    self.selection.value = itertools.find(settings.map, MAPS)
    self.preview = map_preview.for_map(self.selection:get_value())
end

-- The start-menu music plays under this scene; stop it before player-selection
-- starts its own track, or the two overlap.
function MapSelection:_enter_player_selection()
    self:_close_preview()
    audio.stop()
    scenes.set(player_selection.setup())
end

function MapSelection:update(dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        self:_close_preview()
        settings.set_map(self.selection:get_value())
        self:_enter_player_selection()
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        self:_close_preview()
        scenes.set(self.previous_screen)
        return
    end

    local moved = false
    if joysticks.is_pressed_any(joysticks.BUTTONS.RIGHT) then
        moved = self.selection:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.LEFT) then
        moved = self.selection:decrement()
    end

    if moved then
        ok_sound:play()
        self:_close_preview()
        self.preview = map_preview.for_map(self.selection:get_value())
    end

    if self.preview then
        self.preview:update(dt)
    end
end

function MapSelection:_draw_arrows()
    local arrow_y = (screen.HEIGHT + ARROW_AREA_TOP - arrow_left_image:getHeight()) / 2

    if self.selection.value > self.selection.min then
        lutro.graphics.draw(arrow_shade_left_image, 0, 0)
        lutro.graphics.draw(arrow_left_image, ARROW_MARGIN, arrow_y)
    end

    if self.selection.value < self.selection.max then
        local shade_x = screen.WIDTH - arrow_shade_right_image:getWidth()
        lutro.graphics.draw(arrow_shade_right_image, shade_x, 0)
        local right_x = screen.WIDTH - ARROW_MARGIN - arrow_right_image:getWidth()
        lutro.graphics.draw(arrow_right_image, right_x, arrow_y)
    end
end

function MapSelection:_draw_name()
    font:print_centered(self.selection:as_menu_string(), screen.WIDTH, NAME_POSITION)
end

function MapSelection:draw()
    level_graphics.get_graphics_for(self.selection:get_value()):draw_background()
    if self.preview then
        self.preview:draw()
    end
    self:_draw_arrows()
    self:_draw_name()
end

return map_selection
