local points = require("engine.geometry.points")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local level_graphics = require("level_graphics.maps.init")
local arrows = require("menus.arrows")
local items = require("menus.items")
local options_selection = require("options_selection")
local player_selection = require("player_selection")
local block_layout = require("preview.block_layout")
local screen = require("screen")
local settings = require("settings")

local type BlockLayoutPreview = block_layout.BlockLayoutPreview
local type BlockPattern = settings.BlockPattern
local type FallPattern = settings.FallPattern
local type MenuFont = fonts.MenuFont
local type MenuSelection = items.MenuSelection
local type Scene = scenes.Scene

local BLOCK_PATTERNS: {BlockPattern} = {"grid", "empty", "quadrant"}
local FALL_PATTERNS: {FallPattern} = {"left_right", "top_bottom"}

local BLOCK_LAYOUT_FOCUS = 1
local FALL_PATTERN_FOCUS = 2

local BLOCK_LAYOUT_LABEL = "block layout"
local FALL_PATTERN_LABEL = "1-ton pattern"

local BLOCK_LAYOUT_LABEL_Y = 4
local FALL_PATTERN_LABEL_Y = 13

-- Centre the arrows in the screen below the map-name strip rather than the whole
-- screen, so they do not ride up into it.
local ARROW_AREA_TOP = 10

local white_font: MenuFont
local gray_font: MenuFont
local ok_sound: Source

local record MapPatternSettingsScreen is Scene
    previous_screen: Scene
    focus: MenuSelection<integer>
    block_selection: MenuSelection<BlockPattern>
    fall_selection: MenuSelection<FallPattern>
    preview: BlockLayoutPreview
end

local map_pattern_settings_screen = {}

local function next_screen_after(previous_screen: Scene): Scene
    if settings.skip_options_screen then
        return player_selection.setup()
    end
    return options_selection.new(previous_screen)
end

function map_pattern_settings_screen.new(
    previous_screen: Scene
): MapPatternSettingsScreen
    local self: MapPatternSettingsScreen = setmetatable(
        {}, {__index = MapPatternSettingsScreen}
    )
    self.previous_screen = previous_screen
    self.focus = items.new_integer_selection(
        BLOCK_LAYOUT_FOCUS, BLOCK_LAYOUT_FOCUS, FALL_PATTERN_FOCUS
    )
    self.block_selection = items.new_enum_for_value(
        settings.get_block_pattern(), BLOCK_PATTERNS
    )
    self.fall_selection = items.new_enum_for_value(
        settings.get_fall_pattern(), FALL_PATTERNS
    )
    return self
end

function map_pattern_settings_screen.load_assets()
    white_font = fonts.new_menu_white_outlined()
    gray_font = fonts.new_menu_gray_outlined()
    ok_sound = items.ok_sound()
end

function MapPatternSettingsScreen:_is_fall_pattern_focused(): boolean
    return self.focus:get_value() == FALL_PATTERN_FOCUS
end

function MapPatternSettingsScreen:_refresh_preview()
    local falling = self:_is_fall_pattern_focused()
    if not self.preview or self.preview:is_stale(falling) then
        self.preview = block_layout.new(falling)
    end
end

function MapPatternSettingsScreen:load()
    self:_refresh_preview()
end

local function move_selection<T>(selection: MenuSelection<T>): boolean
    if joysticks.is_pressed_any(joysticks.BUTTONS.RIGHT) then
        return selection:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.LEFT) then
        return selection:decrement()
    end
    return false
end

function MapPatternSettingsScreen:_update_active_selection(): boolean
    if self:_is_fall_pattern_focused() then
        local moved = move_selection(self.fall_selection)
        if moved then
            settings.set_fall_pattern(self.fall_selection:get_value())
        end
        return moved
    end

    local moved = move_selection(self.block_selection)
    if moved then
        settings.set_block_pattern(self.block_selection:get_value())
    end
    return moved
end

function MapPatternSettingsScreen:update(dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        scenes.set(next_screen_after(self))
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        scenes.set(self.previous_screen)
        return
    end

    local ok_action = false
    if joysticks.is_pressed_any(joysticks.BUTTONS.DOWN) then
        ok_action = self.focus:increment()
    elseif joysticks.is_pressed_any(joysticks.BUTTONS.UP) then
        ok_action = self.focus:decrement()
    end

    if self:_update_active_selection() then
        ok_action = true
    end

    if ok_action then
        ok_sound:play()
    end

    self:_refresh_preview()
    self.preview:update(dt)
end

function MapPatternSettingsScreen:_draw_preview()
    level_graphics.get_graphics():draw_background()
    self.preview:draw()
end

local function font_for_focus(focus_value: integer, current_focus: integer): MenuFont
    if focus_value == current_focus then
        return white_font
    end
    return gray_font
end

function MapPatternSettingsScreen:_draw_labels()
    local current_focus = self.focus:get_value()
    font_for_focus(BLOCK_LAYOUT_FOCUS, current_focus):print_centered(
        BLOCK_LAYOUT_LABEL, screen.WIDTH, points.new(0, BLOCK_LAYOUT_LABEL_Y)
    )
    font_for_focus(FALL_PATTERN_FOCUS, current_focus):print_centered(
        FALL_PATTERN_LABEL, screen.WIDTH, points.new(0, FALL_PATTERN_LABEL_Y)
    )
end

function MapPatternSettingsScreen:_draw_arrows()
    arrows.draw_shaded(ARROW_AREA_TOP)
end

function MapPatternSettingsScreen:draw()
    self:_draw_preview()
    self:_draw_labels()
    self:_draw_arrows()
end

return map_pattern_settings_screen
