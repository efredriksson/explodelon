local points = require("engine.geometry.points")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local itertools = require("itertools")
local level_graphics = require("level_graphics.maps.init")
local arrows = require("menus.arrows")
local items = require("menus.items")
local options_selection = require("options_selection")
local preview_maps = require("preview.maps.init")
local scripted_battle = require("preview.scripted_battle")
local screen = require("screen")
local settings = require("settings")

local type Map = settings.Map
local type MenuFont = fonts.MenuFont
local type MenuSelection = items.MenuSelection
local type Scene = scenes.Scene
local type ScriptedBattle = scripted_battle.ScriptedBattle

local MAP_ORDER <total>: {Map: integer} = {
    football = 1,
    factory = 2,
    ice_rink = 3,
    bouncing = 4,
}

local MAPS = itertools.in_position_order(MAP_ORDER)

local ARROW_MARGIN = 6

-- Centre the arrows in the screen below the map-name strip rather than the whole
-- screen, so they do not ride up into it.
local ARROW_AREA_TOP = 10

-- Centred on the blue info strip baked into the top of every map background.
local NAME_POSITION = points.new(0, 7)

local font: MenuFont
local ok_sound: Source

local record MapSelection is Scene
    previous_screen: Scene
    selection: MenuSelection<Map>
    preview: ScriptedBattle
end

local map_selection = {}

function map_selection.new(previous_screen: Scene): MapSelection
    local self: MapSelection = setmetatable({}, {__index = MapSelection})
    self.previous_screen = previous_screen
    self.selection = items.new_enum(MAPS)
    return self
end

function map_selection.load_assets()
    font = fonts.new_menu_white_outlined()
    ok_sound = items.ok_sound()
end

-- The preview holds settings.map at whatever it is showing; leave() puts back
-- the map the picker opened on.
function MapSelection:_leave_preview()
    self.preview:leave()
end

function MapSelection:load()
    self.selection.value = itertools.find(settings.map, MAPS)
    local map = self.selection:get_value()
    self.preview = scripted_battle.new(
        preview_maps.scenery_for(map), preview_maps.choreography_for(map)
    )
end

function MapSelection:update(dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        self:_leave_preview()
        settings.set_map(self.selection:get_value())
        scenes.set(options_selection.new(self))
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        self:_leave_preview()
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
        local map = self.selection:get_value()
        self.preview:play(
            preview_maps.scenery_for(map), preview_maps.choreography_for(map)
        )
    end

    self.preview:update(dt)
end

function MapSelection:_draw_arrows()
    local left_image = arrows.left()
    local right_image = arrows.right()
    local arrow_y = (screen.HEIGHT + ARROW_AREA_TOP - left_image:getHeight()) / 2

    if not self.selection:at_min() then
        lutro.graphics.draw(arrows.left_shade(), 0, 0)
        lutro.graphics.draw(left_image, ARROW_MARGIN, arrow_y)
    end

    if not self.selection:at_max() then
        local shade_image = arrows.right_shade()
        lutro.graphics.draw(shade_image, screen.WIDTH - shade_image:getWidth(), 0)
        local right_x = screen.WIDTH - ARROW_MARGIN - right_image:getWidth()
        lutro.graphics.draw(right_image, right_x, arrow_y)
    end
end

function MapSelection:_draw_name()
    font:print_centered(self.selection:as_menu_string(), screen.WIDTH, NAME_POSITION)
end

function MapSelection:draw()
    level_graphics.get_graphics_for(self.selection:get_value()):draw_background()
    self.preview:draw()
    self:_draw_arrows()
    self:_draw_name()
end

return map_selection
