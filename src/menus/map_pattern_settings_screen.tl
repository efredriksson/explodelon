local collision = require("engine.collision")
local points = require("engine.geometry.points")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local hard_blocks = require("hard_blocks")
local itertools = require("itertools")
local level_graphics = require("level_graphics.maps.init")
local map_entities = require("level_layout.map_entities")
local arrows = require("menus.arrows")
local items = require("menus.items")
local options_selection = require("options_selection")
local player_selection = require("player_selection")
local pressure_blocks = require("pressure_block")
local screen = require("screen")
local settings = require("settings")
local soft_blocks = require("soft_blocks")
local z_index = require("z_index")

local type BlockPattern = settings.BlockPattern
local type Entity = require("engine.entity")
local type FallPattern = settings.FallPattern
local type Group = collision.Group
local type HardBlocks = hard_blocks.HardBlocks
local type MenuFont = fonts.MenuFont
local type MenuSelection = items.MenuSelection
local type PressureBlocks = pressure_blocks.PressureBlocks
local type Scene = scenes.Scene
local type SoftBlocks = soft_blocks.SoftBlocks

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

-- Speed up fall pattern animation to show user the pattern faster.
local PREVIEW_FALL_SPEED_MULTIPLIER = 8

local white_font: MenuFont
local gray_font: MenuFont
local ok_sound: Source

local record MapPatternSettingsScreen is Scene
    previous_screen: Scene
    focus: MenuSelection<integer>
    block_selection: MenuSelection<BlockPattern>
    fall_selection: MenuSelection<FallPattern>
    preview_block_pattern: BlockPattern
    preview_fall_pattern: FallPattern
    preview_hard_blocks: HardBlocks
    preview_soft_blocks: SoftBlocks
    preview_pressure_blocks: PressureBlocks
    preview_pressure_blocks_group: Group<Entity>
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

function MapPatternSettingsScreen:_rebuild_preview()
    self.preview_block_pattern = settings.get_block_pattern()
    self.preview_fall_pattern = settings.get_fall_pattern()
    local block_configs = map_entities.get_block_configs({})
    self.preview_hard_blocks = hard_blocks.new(block_configs.hard)
    self.preview_soft_blocks = soft_blocks.new(block_configs.soft)
    self.preview_pressure_blocks = pressure_blocks.new(settings.get_fall_pattern())
    self.preview_pressure_blocks.sudden_death = true
    self.preview_pressure_blocks_group = collision.new_group_from_set(
        self.preview_pressure_blocks.on_ground.set
    )
end

function MapPatternSettingsScreen:_preview_is_stale(): boolean
    return settings.get_block_pattern() ~= self.preview_block_pattern
        or settings.get_fall_pattern() ~= self.preview_fall_pattern
end

function MapPatternSettingsScreen:load()
    self:_rebuild_preview()
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

    local was_fall_pattern_focused = self:_is_fall_pattern_focused()

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

    local is_fall_pattern_focused = self:_is_fall_pattern_focused()
    if
        is_fall_pattern_focused ~= was_fall_pattern_focused or self:_preview_is_stale()
    then
        self:_rebuild_preview()
    end

    if is_fall_pattern_focused then
        self.preview_pressure_blocks:update(dt * PREVIEW_FALL_SPEED_MULTIPLIER)

        local lookup = collision.new_lookup(
            self.preview_soft_blocks.on_ground.set,
            self.preview_hard_blocks.on_ground.set,
            self.preview_pressure_blocks.on_ground.set
        )
        self.preview_soft_blocks.on_ground:cull_if_hit_by(
            lookup, self.preview_pressure_blocks_group
        )
        self.preview_hard_blocks.on_ground:cull_if_hit_by(
            lookup, self.preview_pressure_blocks_group
        )
    end

    self.preview_soft_blocks:update(dt)
end

function MapPatternSettingsScreen:_preview_entities(): {Entity}
    if self:_is_fall_pattern_focused() then
        return itertools.sets_as_list(
            self.preview_pressure_blocks.on_ground.set,
            self.preview_pressure_blocks:falling(),
            self.preview_hard_blocks.on_ground.set,
            self.preview_soft_blocks.on_ground.set
        )
    end
    return itertools.sets_as_list(
        self.preview_hard_blocks.on_ground.set, self.preview_soft_blocks.on_ground.set
    )
end

function MapPatternSettingsScreen:_draw_preview()
    level_graphics.get_graphics():draw_background()

    if self:_is_fall_pattern_focused() then
        local pressure_blocks_with_shadows = itertools.sets_as_list(
            self.preview_pressure_blocks.on_ground.set,
            self.preview_pressure_blocks:falling()
        )
        for _, block in ipairs(pressure_blocks_with_shadows) do
            block:draw_shadow()
        end
    end

    local preview_entities = self:_preview_entities()
    table.sort(preview_entities, z_index.back_to_front)

    for _, entity in ipairs(preview_entities) do
        entity:draw()
    end
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
