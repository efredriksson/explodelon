-- Picks the ruleset between map select and player select.

local points = require("engine.geometry.points")
local joysticks = require("engine.joysticks")
local scenes = require("engine.scenes")
local fonts = require("fonts")
local itertools = require("itertools")
local background = require("level_graphics.background")
local arrows = require("menus.arrows")
local game_rule_screen = require("menus.game_rule_screen")
local items = require("menus.items")
local painting = require("menus.painting")
local player_selection = require("player_selection")
local screen = require("screen")
local settings = require("settings")

local type MenuFont = fonts.MenuFont
local type MenuSelection = items.MenuSelection
local type RulesetName = settings.RulesetName
local type Scene = scenes.Scene

local RULESET_ORDER <total>: {RulesetName: integer} = {
    default = 1,
    insanity = 2,
    bomb_stack = 3,
    dino_madness = 4,
}

local RULESETS = itertools.in_position_order(RULESET_ORDER)

-- Keeps text legible over the map behind.
local WASH_ALPHA = 160

-- Everything the picker owns sits left of this, leaving the lesson cell the rest.
local FLANK_WIDTH = 214

local ARROW_Y = 138
local NAME_POSITION = points.new(0, 144)

local ACCENT_RULE_INSET = 12
local ACCENT_RULE_Y = 172

local HINTS = "press start for more options"
local HINTS_POSITION = points.new(0, 186)

local name_font: MenuFont
local hint_font: MenuFont
local ok_sound: Source

local record OptionsSelection is Scene
    previous_screen: Scene
    selection: MenuSelection<RulesetName>
end

local options_selection = {}

function options_selection.new(previous_screen: Scene): OptionsSelection
    local self: OptionsSelection = setmetatable({}, {__index = OptionsSelection})
    self.previous_screen = previous_screen
    self.selection = items.new_enum(RULESETS)
    return self
end

function options_selection.load_assets()
    name_font = fonts.new_menu_white_outlined_big()
    hint_font = fonts.new_menu_white_outlined()
    ok_sound = items.ok_sound()
end

function OptionsSelection:load()
    self.selection.value = itertools.find(settings.ruleset, RULESETS)
end

function OptionsSelection:update(_dt: number)
    if joysticks.is_pressed_any(joysticks.BUTTONS.B) then
        scenes.set(player_selection.setup())
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.A) then
        scenes.set(self.previous_screen)
        return
    end

    if joysticks.is_pressed_any(joysticks.BUTTONS.START) then
        scenes.set(game_rule_screen.new(self))
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
        settings.set_ruleset(self.selection:get_value())
    end
end

-- Nothing resets the draw colour between scenes, and menu screens leave it grey.
local function reset_draw_color()
    painting.set_color(painting.WHITE)
end

function OptionsSelection:_draw_washed_map()
    reset_draw_color()
    background.draw()
    painting.fill_rect(0, 0, screen.WIDTH, screen.HEIGHT, painting.BLACK, WASH_ALPHA)
    reset_draw_color()
end

function OptionsSelection:_draw_arrows()
    if not self.selection:at_min() then
        lutro.graphics.draw(arrows.left(), 0, ARROW_Y)
    end

    if not self.selection:at_max() then
        local right_image = arrows.right()
        lutro.graphics.draw(right_image, FLANK_WIDTH - right_image:getWidth(), ARROW_Y)
    end
end

function OptionsSelection:_draw_flank()
    name_font:print_centered(
        self.selection:as_menu_string(), FLANK_WIDTH, NAME_POSITION
    )
    hint_font:print_centered(HINTS, FLANK_WIDTH, HINTS_POSITION)
end

function OptionsSelection:_draw_accent_rule()
    painting.draw_hline(
        ACCENT_RULE_INSET,
        FLANK_WIDTH - 1 - ACCENT_RULE_INSET,
        ACCENT_RULE_Y,
        painting.WHITE
    )
end

function OptionsSelection:draw()
    self:_draw_washed_map()
    self:_draw_arrows()
    self:_draw_flank()
    self:_draw_accent_rule()
end

return options_selection
