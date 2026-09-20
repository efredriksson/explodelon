-- Picking the map, the block layout and the 1-ton pattern, on one screen that
-- previews whichever of the three the player is looking at.

local points = require("engine.geometry.points")
local images = require("engine.images")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local itertools = require("itertools")
local level_graphics = require("level_graphics.maps.init")
local arrows = require("menus.arrows")
local items = require("menus.items")
local painting = require("menus.painting")
local options_selection = require("options_selection")
local player_selection = require("player_selection")
local block_layout = require("preview.block_layout")
local choreography = require("preview.choreography")
local preview_maps = require("preview.maps.init")
local scenery = require("preview.scenery")
local scripted_battle = require("preview.scripted_battle")
local screen = require("screen")
local settings = require("settings")

local type BlockLayoutPreview = block_layout.BlockLayoutPreview
local type BlockPattern = settings.BlockPattern
local type Choreography = choreography.Choreography
local type Color = images.Color
local type FallPattern = settings.FallPattern
local type Map = settings.Map
local type MenuFont = fonts.MenuFont
local type MenuSelection = items.MenuSelection
local type Scene = scenes.Scene
local type Scenery = scenery.Scenery
local type ScriptedBattle = scripted_battle.ScriptedBattle

local MAP_ORDER <total>: {Map: integer} = {
    football = 1,
    factory = 2,
    ice_rink = 3,
    bouncing = 4,
}

local MAPS = itertools.in_position_order(MAP_ORDER)
local BLOCK_PATTERNS: {BlockPattern} = {"grid", "empty", "quadrant"}
local FALL_PATTERNS: {FallPattern} = {"left_right", "top_bottom"}

local enum Row
    "map"
    "block layout"
    "1-ton pattern"
end

local ROWS: {Row} = {"map", "block layout", "1-ton pattern"}

-- The blue strip is baked into all four map backgrounds, eighteen pixels of it,
-- and an outlined line of text is seven, so only one row fits at a time.
local ROW_Y = 8
local ROW_INK_HEIGHT = 7
local ROW_POSITION = points.new(0, ROW_Y)

-- A CRT can eat a tenth of the picture, so the column stays clear of the edge,
-- and the current dot is larger as well as brighter to survive the blur.
local DOT_CENTER_X = 280
local DOT_PITCH = 5
local DOT_SIZE = 3
local FOCUSED_DOT_SIZE = 5
local FADED_DOT: Color = {152, 168, 184}

local TEXT_CENTER_Y = ROW_Y + math.floor(ROW_INK_HEIGHT / 2)
local FIRST_DOT_CENTER_Y = TEXT_CENTER_Y - DOT_PITCH

local ARROW_AREA_TOP = 10

local white_font: MenuFont
local ok_sound: Source

local record MapSetup is Scene
    focus: MenuSelection<Row>
    map_choice: MenuSelection<Map>
    block_choice: MenuSelection<BlockPattern>
    fall_choice: MenuSelection<FallPattern>
    battle_preview: ScriptedBattle
    layout_preview: BlockLayoutPreview
end

local map_setup = {}

local function new_block_choice(): MenuSelection<BlockPattern>
    return items.new_enum_for_value(settings.get_block_pattern(), BLOCK_PATTERNS)
end

local function new_fall_choice(): MenuSelection<FallPattern>
    return items.new_enum_for_value(settings.get_fall_pattern(), FALL_PATTERNS)
end

function map_setup.new(): MapSetup
    local self: MapSetup = setmetatable({}, {__index = MapSetup})
    self.focus = items.new_enum(ROWS)
    return self
end

function map_setup.load_assets()
    white_font = fonts.new_menu_white_outlined()
    ok_sound = items.ok_sound()
end

function MapSetup:_showing_battle(): boolean
    return self.focus:get_value() == "map"
end

function MapSetup:_showing_fall_pattern(): boolean
    return self.focus:get_value() == "1-ton pattern"
end

local function battle_on(map: Map): Scenery, Choreography
    return preview_maps.scenery_for(map), preview_maps.choreography_for(map)
end

function MapSetup:load()
    self.map_choice = items.new_enum_for_value(settings.map, MAPS)
    self.block_choice = new_block_choice()
    self.fall_choice = new_fall_choice()
end

function MapSetup:_refresh_battle_preview()
    if self.battle_preview then
        return
    end
    self.battle_preview = scripted_battle.new(battle_on(settings.map))
end

function MapSetup:_refresh_layout_preview()
    local falling = self:_showing_fall_pattern()
    if not self.layout_preview or self.layout_preview:is_stale(falling) then
        self.layout_preview = block_layout.new(falling)
    end
end

-- The screen is entered mid-update, so its first frame draws before it updates.
-- Both ends ask, rather than one trusting the other to have built the preview.
function MapSetup:_refresh_focused_preview()
    if self:_showing_battle() then
        self:_refresh_battle_preview()
        return
    end
    self:_refresh_layout_preview()
end

local function move_choice<T>(choice: MenuSelection<T>): boolean
    if joysticks.is_pressed_any(joysticks.BUTTONS.RIGHT) then
        return choice:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.LEFT) then
        return choice:decrement()
    end
    return false
end

local function move_and_apply<T>(choice: MenuSelection<T>, apply: function(T)): boolean
    if not move_choice(choice) then
        return false
    end
    apply(choice:get_value())
    return true
end

function MapSetup:_restart_battle_preview()
    if self.battle_preview then
        self.battle_preview:play(battle_on(settings.map))
    end
end

-- The map applies as it is scrolled past, so nothing on screen can disagree
-- about which map this is. Both patterns are kept per map, so the rows below it
-- have to be re-read for the one just arrived at.
function MapSetup:_move_map(): boolean
    if not move_choice(self.map_choice) then
        return false
    end
    settings.set_map(self.map_choice:get_value())
    self.block_choice = new_block_choice()
    self.fall_choice = new_fall_choice()
    self:_restart_battle_preview()
    return true
end

function MapSetup:_move_block_layout(): boolean
    return move_and_apply(self.block_choice, settings.set_block_pattern)
end

function MapSetup:_move_fall_pattern(): boolean
    return move_and_apply(self.fall_choice, settings.set_fall_pattern)
end

function MapSetup:_move_focused_choice(): boolean
    if self:_showing_battle() then
        return self:_move_map()
    elseif self:_showing_fall_pattern() then
        return self:_move_fall_pattern()
    end
    return self:_move_block_layout()
end

function MapSetup:_move_focus(): boolean
    if joysticks.is_pressed_any(joysticks.BUTTONS.DOWN) then
        return self.focus:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.UP) then
        return self.focus:decrement()
    end
    return false
end

local function next_screen_after(map_screen: Scene): Scene
    if settings.skip_options_screen then
        return player_selection.setup()
    end
    return options_selection.new(map_screen)
end

function MapSetup:update(dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        scenes.set(next_screen_after(self))
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        scenes.return_to_start()
        return
    end

    local moved_focus = self:_move_focus()
    local moved_choice = self:_move_focused_choice()
    if moved_focus or moved_choice then
        ok_sound:play()
    end

    self:_refresh_focused_preview()
    if self:_showing_battle() then
        self.battle_preview:update(dt)
        return
    end
    self.layout_preview:update(dt)
end

function MapSetup:_focused_row_text(): string
    if self:_showing_battle() then
        return self.map_choice:as_menu_string()
    end
    return self.focus:get_value()
end

function MapSetup:_draw_focused_row()
    white_font:print_centered(self:_focused_row_text(), screen.WIDTH, ROW_POSITION)
end

local function dot_size_and_tint(on_this_row: boolean): number, Color
    if on_this_row then
        return FOCUSED_DOT_SIZE, painting.WHITE
    end
    return DOT_SIZE, FADED_DOT
end

function MapSetup:_draw_dots()
    for place = 1, #ROWS do
        local size, tint = dot_size_and_tint(place == self.focus.value)
        painting.fill_square_centered(
            DOT_CENTER_X, FIRST_DOT_CENTER_Y + (place - 1) * DOT_PITCH, size, tint
        )
    end
end

function MapSetup:draw()
    level_graphics.get_graphics():draw_background()
    self:_refresh_focused_preview()
    if self:_showing_battle() then
        self.battle_preview:draw()
    else
        self.layout_preview:draw()
    end
    arrows.draw_shaded(ARROW_AREA_TOP)
    self:_draw_focused_row()
    self:_draw_dots()
end

return map_setup
